# Design und Empfehlungen für eine Pokémon GO Datenbank mit Internationalisierung (i18n)

## Überblick

Dieses Dokument enthält eine vollständige, strukturierte Darstellung des
empfohlenen Datenbankdesigns zur Verwaltung von Pokémon-GO-Daten mit
sauberer Internationalisierung, Suchbegriffen, Übersetzungen und
Stammdatenstrukturen.\
Es basiert vollständig auf der vorherigen ausführlichen Antwort.

------------------------------------------------------------------------

## 1. Designziele

### 🎯 Trennung von Identität vs. Darstellung

-   IDs und Schlüssel bleiben sprachunabhängig.
-   Übersetzungen in separaten Tabellen (FK-gebunden).
-   Suchbegriffe getrennt von offiziellen Namen.

### 🎯 Wartbarkeit

-   Klare Tabellen pro Domain (pokemon, move, type, region, form).
-   Separate \*\_name-Tabellen für Übersetzungen.
-   Keine generische „translation"-Tabelle für Gameplay-Objekte (nur für
    UI-Strings sinnvoll).

### 🎯 Saubere Suche

-   Tokens (Aliasse, Synonyme, Operatoren) getrennt.
-   Volltext-, Normalisierungs- und Fuzzy-Indizes möglich.
-   Unterstützung pro Sprache für Befehle wie „schillernd", „feuer",
    „entwickeln".

### 🎯 Performance

-   `lower(unaccent())` für schnelle Suche.
-   `pg_trgm` für fuzzy Matching.
-   Durchdachte Indizes auf Namen, Normalisierungen und Token-Spalten.

### 🎯 Fallback

-   Standardsprachwert (z. B. EN) garantiert.
-   SQL via `COALESCE`.

### 🎯 Erweiterbarkeit

-   Neue Sprachen = nur Einträge in \*\_name + Tokens.
-   Keine Stammdatenänderung nötig.

------------------------------------------------------------------------

## 2. Sprachspezifische Tabellen

``` sql
CREATE TABLE language (
  language_id   serial PRIMARY KEY,
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  is_default    boolean NOT NULL DEFAULT false,
  is_rtl        boolean NOT NULL DEFAULT false
);
```

------------------------------------------------------------------------

## 3. Stammdaten-Tabellen (sprachneutral)

### Regionen, Typen, Moves, Formen, Pokémon

``` sql
CREATE TABLE region (
  region_id   serial PRIMARY KEY,
  key         text NOT NULL UNIQUE,
  generation  smallint NOT NULL
);

CREATE TABLE "type" (
  type_id     serial PRIMARY KEY,
  key         text NOT NULL UNIQUE
);

CREATE TABLE move (
  move_id     serial PRIMARY KEY,
  key         text NOT NULL UNIQUE,
  type_id     int NOT NULL REFERENCES "type"(type_id),
  category    text NOT NULL CHECK (category IN ('fast','charged')),
  power       integer,
  energy      integer,
  duration_ms integer
);

CREATE TABLE form (
  form_id     serial PRIMARY KEY,
  key         text NOT NULL UNIQUE
);

CREATE TABLE pokemon (
  pokemon_id  serial PRIMARY KEY,
  dex_no      integer NOT NULL,
  default_form_id int REFERENCES form(form_id),
  type1_id    int NOT NULL REFERENCES "type"(type_id),
  type2_id    int REFERENCES "type"(type_id),
  region_id   int REFERENCES region(region_id),
  slug        text UNIQUE
);
```

------------------------------------------------------------------------

## 4. Übersetzungstabellen (offizielle Namen)

``` sql
CREATE TABLE pokemon_name (
  pokemon_id   int NOT NULL REFERENCES pokemon(pokemon_id) ON DELETE CASCADE,
  language_id  int NOT NULL REFERENCES language(language_id),
  display_name text NOT NULL,
  sort_name    text,
  PRIMARY KEY (pokemon_id, language_id)
);

CREATE INDEX ix_pokemon_name_search
  ON pokemon_name (lower(unaccent(display_name)));
```

Ebenso für: - move_name\
- type_name\
- region_name\
- form_name

------------------------------------------------------------------------

## 5. Such-Token-System

### Allgemeine Token-Tabelle

``` sql
CREATE TYPE token_domain AS ENUM ('pokemon','move','type','region','form','operator');

CREATE TABLE search_token (
  token_id     serial PRIMARY KEY,
  language_id  int NOT NULL REFERENCES language(language_id),
  domain       token_domain NOT NULL,
  token        text NOT NULL,
  normalized   text GENERATED ALWAYS AS (lower(unaccent(token))) STORED,
  priority     smallint NOT NULL DEFAULT 0,
  is_official  boolean NOT NULL DEFAULT false,
  UNIQUE (language_id, domain, normalized)
);
```

### Referenztabellen für Tokens

``` sql
CREATE TABLE search_token_ref_pokemon (
  token_id   int NOT NULL REFERENCES search_token(token_id) ON DELETE CASCADE,
  pokemon_id int NOT NULL REFERENCES pokemon(pokemon_id) ON DELETE CASCADE,
  PRIMARY KEY (token_id, pokemon_id)
);
```

Ähnliche Tabellen für Moves, Typen und Formen.

### Operator-Token

``` sql
CREATE TABLE search_operator (
  operator_key text PRIMARY KEY,
  param_kind   text NOT NULL CHECK (
    param_kind IN ('none','text','number','boolean','type','region','form','pokemon','move')
  )
);

CREATE TABLE search_operator_token (
  operator_key text NOT NULL REFERENCES search_operator(operator_key),
  language_id  int NOT NULL REFERENCES language(language_id),
  token        text NOT NULL,
  normalized   text GENERATED ALWAYS AS (lower(unaccent(token))) STORED,
  PRIMARY KEY (operator_key, language_id, normalized)
);
```

------------------------------------------------------------------------

## 6. Beispielabfragen

### Pokémon-Name mit Sprachfallback

``` sql
SELECT COALESCE(
  (SELECT display_name FROM pokemon_name pn
      JOIN language l ON l.language_id = pn.language_id
      WHERE pn.pokemon_id = $1 AND l.code = $2),
  (SELECT display_name FROM pokemon_name pn
      JOIN language l ON l.language_id = pn.language_id
      WHERE pn.pokemon_id = $1 AND l.is_default = true)
) AS name;
```

### Token-Suche (inkl. Fuzzy Matching)

``` sql
WITH t AS (SELECT lower(unaccent($1)) AS q)
SELECT st.*, p.pokemon_id, m.move_id
FROM t
JOIN language l ON l.code = 'de'
LEFT JOIN search_token st ON st.language_id = l.language_id
 AND (st.normalized = t.q OR st.normalized % t.q)
LEFT JOIN search_token_ref_pokemon rpp ON rpp.token_id = st.token_id
LEFT JOIN pokemon p ON p.pokemon_id = rpp.pokemon_id;
```

------------------------------------------------------------------------

## 7. Index-Empfehlungen

-   `lower(unaccent(name))` auf allen \*\_name-Tabellen\
-   GIN-Trigramm-Index auf `search_token.normalized`\
-   Sortier-Collation: `COLLATE "de_DE.utf8"` bei Bedarf\
-   Normierte Suchspalten für Geschwindigkeit

------------------------------------------------------------------------

## 8. Generische UI-Strings (optionale Hybrid-Lösung)

``` sql
CREATE TABLE i18n_string (
  key         text NOT NULL,
  language_id int NOT NULL REFERENCES language(language_id),
  value       text NOT NULL,
  PRIMARY KEY (key, language_id)
);
```

------------------------------------------------------------------------

## 9. Datenpflege-Workflow

1.  Stammdaten laden (Pokédex, Typen, Regionen, Moves).\
2.  Übersetzungen je Sprache in \*\_name füllen.\
3.  Synonyme/Aliasse in search_token + ref-Tabellen pflegen.\
4.  Operatoren + sprachspezifische Befehle hinzufügen.\
5.  Tests:
    -   Jede Entität hat EN-Fallback\
    -   Normalisierungsregeln greifen\
    -   Operatoren funktionieren in allen Sprachen

------------------------------------------------------------------------

## 10. Zusammenfassung / TL;DR

-   Saubere Trennung: **Stammdaten → Übersetzungen → Suchbegriffe**\
-   Für jede Domäne spezifische \*\_name Tabellen\
-   Separate Token-Struktur für Suche\
-   Sprachfallback, Normalisierung & starke Indizes\
-   Erweiterbar ohne Schemaänderungen
