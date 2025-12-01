-- ============================================================================
-- Pokémon GO Database Schema
-- ============================================================================
-- 
-- A comprehensive, internationalized database design for Pokémon GO data
-- 
-- Design Principles:
-- - Separation of identity vs. display (IDs language-neutral, names translated)
-- - Maintainability (clear domain tables, separate translation tables)
-- - Clean search (tokens/aliases separate from official names)
-- - Performance (normalized search columns, strategic indexes)
-- - Fallback support (default language guaranteed)
-- - Extensibility (new languages = new translations only)
--
-- All string columns use TEXT type for flexibility and performance
-- ============================================================================

-- ============================================================================
-- CORE: Language Support
-- ============================================================================

CREATE TABLE language (
  language_id   serial PRIMARY KEY,
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  is_default    boolean NOT NULL DEFAULT false,
  is_rtl        boolean NOT NULL DEFAULT false
);

COMMENT ON TABLE language IS 'Supported languages for internationalization';
COMMENT ON COLUMN language.code IS 'ISO 639-1 language code (e.g., "en", "de", "ja")';
COMMENT ON COLUMN language.is_default IS 'Default/fallback language';
COMMENT ON COLUMN language.is_rtl IS 'Right-to-left script (e.g., Arabic, Hebrew)';

CREATE INDEX ix_language_default ON language(is_default) WHERE is_default = true;

-- ============================================================================
-- DOMAIN: Weather
-- ============================================================================

CREATE TABLE weather (
  weather_id    serial PRIMARY KEY,
  key           text NOT NULL UNIQUE,
  icon          text,
  boost_type_id int REFERENCES "type"(type_id),
  sort_order    smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE weather IS 'Weather conditions in Pokémon GO';
COMMENT ON COLUMN weather.icon IS 'Icon identifier or path';

CREATE TABLE weather_name (
  weather_id    int NOT NULL REFERENCES weather(weather_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  description   text,
  PRIMARY KEY (weather_id, language_id)
);

CREATE INDEX ix_weather_name_search ON weather_name (lower(unaccent(display_name)));

-- ============================================================================
-- DOMAIN: Types
-- ============================================================================

CREATE TABLE "type" (
  type_id       serial PRIMARY KEY,
  key           text NOT NULL UNIQUE,
  icon          text,
  color_hex     text,
  sort_order    smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE "type" IS 'Pokémon types (e.g., Fire, Water, Grass)';
COMMENT ON COLUMN "type".icon IS 'Icon identifier or path';
COMMENT ON COLUMN "type".color_hex IS 'Display color for UI (e.g., "#FF0000")';

CREATE TABLE type_name (
  type_id       int NOT NULL REFERENCES "type"(type_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  PRIMARY KEY (type_id, language_id)
);

CREATE INDEX ix_type_name_search ON type_name (lower(unaccent(display_name)));

-- ============================================================================
-- DOMAIN: Type Interactions
-- ============================================================================

CREATE TABLE interaction_type (
  interaction_type_id serial PRIMARY KEY,
  key                 text NOT NULL UNIQUE,
  multiplier          numeric(3,2) NOT NULL,
  sort_order          smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE interaction_type IS 'Type effectiveness categories (e.g., super_effective, not_very_effective)';
COMMENT ON COLUMN interaction_type.multiplier IS 'Damage multiplier (e.g., 1.6, 0.625, 0.390625)';

CREATE TABLE interaction_name (
  interaction_type_id int NOT NULL REFERENCES interaction_type(interaction_type_id) ON DELETE CASCADE,
  language_id         int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name        text NOT NULL,
  PRIMARY KEY (interaction_type_id, language_id)
);

CREATE TABLE type_interaction (
  attacking_type_id   int NOT NULL REFERENCES "type"(type_id) ON DELETE CASCADE,
  defending_type_id   int NOT NULL REFERENCES "type"(type_id) ON DELETE CASCADE,
  interaction_type_id int NOT NULL REFERENCES interaction_type(interaction_type_id),
  PRIMARY KEY (attacking_type_id, defending_type_id)
);

COMMENT ON TABLE type_interaction IS 'Type effectiveness chart (attacking vs defending types)';

CREATE INDEX ix_type_interaction_attack ON type_interaction(attacking_type_id);
CREATE INDEX ix_type_interaction_defend ON type_interaction(defending_type_id);

-- ============================================================================
-- DOMAIN: Adventure Effects
-- ============================================================================

CREATE TABLE adventure_effect (
  adventure_effect_id serial PRIMARY KEY,
  key                 text NOT NULL UNIQUE,
  sort_order          smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE adventure_effect IS 'Buddy adventure perk effects';

CREATE TABLE adventure_effect_name (
  adventure_effect_id int NOT NULL REFERENCES adventure_effect(adventure_effect_id) ON DELETE CASCADE,
  language_id         int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name        text NOT NULL,
  description         text,
  PRIMARY KEY (adventure_effect_id, language_id)
);

-- ============================================================================
-- DOMAIN: Move Categories and Tags
-- ============================================================================

CREATE TABLE move_category (
  move_category_id serial PRIMARY KEY,
  key              text NOT NULL UNIQUE,
  sort_order       smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE move_category IS 'Move categories: fast, charged';

CREATE TABLE move_category_name (
  move_category_id int NOT NULL REFERENCES move_category(move_category_id) ON DELETE CASCADE,
  language_id      int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name     text NOT NULL,
  PRIMARY KEY (move_category_id, language_id)
);

CREATE TABLE move_tag (
  move_tag_id   serial PRIMARY KEY,
  key           text NOT NULL UNIQUE,
  sort_order    smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE move_tag IS 'Move tags/properties (e.g., legacy, elite, signature)';

-- ============================================================================
-- DOMAIN: Moves
-- ============================================================================

CREATE TABLE move (
  move_id               serial PRIMARY KEY,
  key                   text NOT NULL UNIQUE,
  type_id               int NOT NULL REFERENCES "type"(type_id),
  move_category_id      int NOT NULL REFERENCES move_category(move_category_id),
  adventure_effect_id   int REFERENCES adventure_effect(adventure_effect_id),
  power                 integer,
  energy                integer,
  duration_ms           integer,
  animation_duration_ms integer,
  damage_window_start_ms integer,
  damage_window_end_ms  integer,
  -- Raid-specific stats
  raid_power            integer,
  raid_energy           integer,
  raid_dps              numeric(6,2),
  raid_eps              numeric(6,2),
  raid_dpe              numeric(5,2),
  -- PvP-specific stats
  pvp_power             integer,
  pvp_energy            integer,
  pvp_dps               numeric(6,2),
  pvp_eps               numeric(6,2),
  pvp_dpe               numeric(5,2),
  -- Calculated fields
  dpe                   numeric(5,2) GENERATED ALWAYS AS (
    CASE
      WHEN energy IS NOT NULL AND energy != 0 THEN (power::numeric / energy::numeric)
      ELSE NULL
    END
  ) STORED,
  is_legacy             boolean NOT NULL DEFAULT false,
  special_effect        text
);

COMMENT ON TABLE move IS 'Pokémon moves/attacks with detailed mechanics';
COMMENT ON COLUMN move.power IS 'Base power';
COMMENT ON COLUMN move.energy IS 'Energy cost/generation';
COMMENT ON COLUMN move.duration_ms IS 'Total move duration in milliseconds';
COMMENT ON COLUMN move.animation_duration_ms IS 'Animation duration in milliseconds';
COMMENT ON COLUMN move.damage_window_start_ms IS 'Damage window start time in milliseconds';
COMMENT ON COLUMN move.damage_window_end_ms IS 'Damage window end time in milliseconds';
COMMENT ON COLUMN move.raid_power IS 'Power in raid battles';
COMMENT ON COLUMN move.raid_energy IS 'Energy in raid battles';
COMMENT ON COLUMN move.raid_dps IS 'Damage per second in raids (calculated)';
COMMENT ON COLUMN move.raid_eps IS 'Energy per second in raids (calculated)';
COMMENT ON COLUMN move.raid_dpe IS 'Damage per energy in raids (calculated)';
COMMENT ON COLUMN move.pvp_power IS 'Power in PvP battles';
COMMENT ON COLUMN move.pvp_energy IS 'Energy in PvP battles';
COMMENT ON COLUMN move.pvp_dps IS 'Damage per second in PvP (calculated)';
COMMENT ON COLUMN move.pvp_eps IS 'Energy per second in PvP (calculated)';
COMMENT ON COLUMN move.pvp_dpe IS 'Damage per energy in PvP (calculated)';
COMMENT ON COLUMN move.dpe IS 'Damage per energy (calculated)';
COMMENT ON COLUMN move.special_effect IS 'Special move effects (WiP)';

CREATE TABLE move_name (
  move_id       int NOT NULL REFERENCES move(move_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  description   text,
  PRIMARY KEY (move_id, language_id)
);

CREATE INDEX ix_move_name_search ON move_name (lower(unaccent(display_name)));

CREATE TABLE move_has_tag (
  move_id       int NOT NULL REFERENCES move(move_id) ON DELETE CASCADE,
  move_tag_id   int NOT NULL REFERENCES move_tag(move_tag_id) ON DELETE CASCADE,
  PRIMARY KEY (move_id, move_tag_id)
);

-- ============================================================================
-- DOMAIN: Regions
-- ============================================================================

CREATE TABLE region (
  region_id   serial PRIMARY KEY,
  key         text NOT NULL UNIQUE,
  generation  smallint NOT NULL,
  sort_order  smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE region IS 'Pokémon regions/generations (Kanto, Johto, etc.)';

CREATE TABLE region_name (
  region_id     int NOT NULL REFERENCES region(region_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  PRIMARY KEY (region_id, language_id)
);

CREATE INDEX ix_region_name_search ON region_name (lower(unaccent(display_name)));

-- ============================================================================
-- DOMAIN: Evolution Stages
-- ============================================================================

CREATE TABLE stage (
  stage_id    serial PRIMARY KEY,
  key         text NOT NULL UNIQUE,
  stage_num   smallint NOT NULL,
  sort_order  smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE stage IS 'Evolution stages (basic, stage1, stage2, mega, etc.)';

CREATE TABLE stage_name (
  stage_id      int NOT NULL REFERENCES stage(stage_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  PRIMARY KEY (stage_id, language_id)
);

-- ============================================================================
-- DOMAIN: Resource Types
-- ============================================================================

CREATE TABLE resource_type (
  resource_type_id serial PRIMARY KEY,
  key              text NOT NULL UNIQUE,
  sort_order       smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE resource_type IS 'Resource types (stardust, candy, candy_xl, etc.)';

CREATE TABLE resource_type_name (
  resource_type_id int NOT NULL REFERENCES resource_type(resource_type_id) ON DELETE CASCADE,
  language_id      int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name     text NOT NULL,
  PRIMARY KEY (resource_type_id, language_id)
);

-- ============================================================================
-- DOMAIN: Evolution Items
-- ============================================================================

CREATE TABLE evolution_item (
  evolution_item_id serial PRIMARY KEY,
  key               text NOT NULL UNIQUE,
  icon              text,
  sort_order        smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE evolution_item IS 'Special evolution items (Sun Stone, Metal Coat, etc.)';

CREATE TABLE evolution_item_name (
  evolution_item_id int NOT NULL REFERENCES evolution_item(evolution_item_id) ON DELETE CASCADE,
  language_id       int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name      text NOT NULL,
  description       text,
  PRIMARY KEY (evolution_item_id, language_id)
);

-- ============================================================================
-- DOMAIN: Colors
-- ============================================================================

CREATE TABLE color (
  color_id    serial PRIMARY KEY,
  key         text NOT NULL UNIQUE,
  hex_value   text,
  sort_order  smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE color IS 'Pokédex colors';

CREATE TABLE color_name (
  color_id      int NOT NULL REFERENCES color(color_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  PRIMARY KEY (color_id, language_id)
);

-- ============================================================================
-- DOMAIN: Pokémon (Core Entity)
-- ============================================================================

CREATE TABLE pokemon (
  pokemon_id        serial PRIMARY KEY,
  dex_no            integer NOT NULL,
  generation        smallint,
  region_id         int REFERENCES region(region_id),
  form_code         text NOT NULL DEFAULT 'base',
  slug              text UNIQUE,
  type1_id          int NOT NULL REFERENCES "type"(type_id),
  type2_id          int REFERENCES "type"(type_id),
  attack            smallint NOT NULL,
  defense           smallint NOT NULL,
  stamina           smallint NOT NULL,
  buddy_distance    smallint CONSTRAINT chk_buddy_distance CHECK (buddy_distance IN (1, 3, 5, 20)),
  stage_id          int REFERENCES stage(stage_id),
  color_id          int REFERENCES color(color_id),
  family_id         int REFERENCES pokemon(pokemon_id),
  evolves_from_id   int REFERENCES pokemon(pokemon_id),
  candy_cost        smallint,
  mega_energy_cost  integer,
  purification_cost integer,
  evolution_item_id int REFERENCES evolution_item(evolution_item_id),
  height            numeric(4,1),
  weight            numeric(5,1),
  base_catch_rate   numeric(3,2),
  base_flee_rate    numeric(3,2),
  catch_candy       smallint,
  catch_stardust    smallint,
  move_add_candy    smallint,
  move_add_stardust smallint,
  is_legendary      boolean NOT NULL DEFAULT false,
  is_mythical       boolean NOT NULL DEFAULT false,
  is_ultra_beast    boolean NOT NULL DEFAULT false,
  is_mega           boolean NOT NULL DEFAULT false,
  is_shadow         boolean NOT NULL DEFAULT false,
  is_released       boolean NOT NULL DEFAULT true,
  is_shiny_released boolean NOT NULL DEFAULT false,
  is_tradeable      boolean NOT NULL DEFAULT true,
  is_sword_shield_available boolean DEFAULT false,
  is_scarlet_violet_available boolean DEFAULT false,
  is_home_transferrable boolean DEFAULT false,
  release_date      date,
  shiny_release_date date,
  gym_defender_rank smallint,
  CONSTRAINT chk_types CHECK (type1_id != type2_id OR type2_id IS NULL),
  CONSTRAINT chk_generation CHECK (generation BETWEEN 1 AND 9),
  CONSTRAINT chk_stage CHECK (stage_id >= -1 AND stage_id <= 2),
  UNIQUE (dex_no, form_code)
);

COMMENT ON TABLE pokemon IS 'Core Pokémon entities with base stats and game mechanics';
COMMENT ON COLUMN pokemon.dex_no IS 'Pokédex number (1, 2, 3, 4, 5, 6, 7, ...)';
COMMENT ON COLUMN pokemon.generation IS 'Pokémon generation (1-9)';
COMMENT ON COLUMN pokemon.form_code IS 'Form identifier (base, M, MX, MY, Gm, A, G, H, ...)';
COMMENT ON COLUMN pokemon.slug IS 'URL-friendly identifier (e.g., "pikachu", "charizard-mega-x")';
COMMENT ON COLUMN pokemon.attack IS 'Base attack stat';
COMMENT ON COLUMN pokemon.defense IS 'Base defense stat';
COMMENT ON COLUMN pokemon.stamina IS 'Base stamina stat';
COMMENT ON COLUMN pokemon.buddy_distance IS 'Buddy walking distance requirement (1, 3, 5, 20 km)';
COMMENT ON COLUMN pokemon.family_id IS 'Family group identifier';
COMMENT ON COLUMN pokemon.evolves_from_id IS 'Direct evolution predecessor';
COMMENT ON COLUMN pokemon.candy_cost IS 'Candy cost for evolution from previous stage';
COMMENT ON COLUMN pokemon.mega_energy_cost IS 'Mega energy cost for evolution from previous stage';
COMMENT ON COLUMN pokemon.purification_cost IS 'Purification cost for shadow Pokémon';
COMMENT ON COLUMN pokemon.height IS 'Height in meters';
COMMENT ON COLUMN pokemon.weight IS 'Weight in kg';
COMMENT ON COLUMN pokemon.base_catch_rate IS 'Base catch rate (0.00-1.00)';
COMMENT ON COLUMN pokemon.base_flee_rate IS 'Base flee rate (0.00-1.00)';
COMMENT ON COLUMN pokemon.catch_candy IS 'Candy reward for catching';
COMMENT ON COLUMN pokemon.catch_stardust IS 'Stardust reward for catching';
COMMENT ON COLUMN pokemon.move_add_candy IS 'Additional candy for catching with specific moves';
COMMENT ON COLUMN pokemon.move_add_stardust IS 'Additional stardust for catching with specific moves';
COMMENT ON COLUMN pokemon.is_shiny_released IS 'Whether shiny version is available';
COMMENT ON COLUMN pokemon.is_tradeable IS 'Whether Pokémon can be traded';
COMMENT ON COLUMN pokemon.is_sword_shield_available IS 'Available in Pokémon Sword/Shield';
COMMENT ON COLUMN pokemon.is_scarlet_violet_available IS 'Available in Pokémon Scarlet/Violet';
COMMENT ON COLUMN pokemon.is_home_transferrable IS 'Can be transferred to Pokémon HOME';
COMMENT ON COLUMN pokemon.release_date IS 'Release date in Pokémon GO';
COMMENT ON COLUMN pokemon.shiny_release_date IS 'Shiny release date in Pokémon GO';
COMMENT ON COLUMN pokemon.gym_defender_rank IS 'Gym defender eligibility rank';

CREATE INDEX ix_pokemon_dex ON pokemon(dex_no);
CREATE INDEX ix_pokemon_generation ON pokemon(generation);
CREATE INDEX ix_pokemon_form ON pokemon(form_code);
CREATE INDEX ix_pokemon_type1 ON pokemon(type1_id);
CREATE INDEX ix_pokemon_type2 ON pokemon(type2_id) WHERE type2_id IS NOT NULL;
CREATE INDEX ix_pokemon_region ON pokemon(region_id);
CREATE INDEX ix_pokemon_family ON pokemon(family_id);
CREATE INDEX ix_pokemon_evolves_from ON pokemon(evolves_from_id);
CREATE INDEX ix_pokemon_released ON pokemon(is_released) WHERE is_released = true;
CREATE INDEX ix_pokemon_legendary ON pokemon(is_legendary) WHERE is_legendary = true;
CREATE INDEX ix_pokemon_mythical ON pokemon(is_mythical) WHERE is_mythical = true;

CREATE TABLE pokemon_name (
  pokemon_id    int NOT NULL REFERENCES pokemon(pokemon_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  sort_name     text,
  genus         text,
  PRIMARY KEY (pokemon_id, language_id)
);

COMMENT ON COLUMN pokemon_name.genus IS 'Species category (e.g., "Mouse Pokémon", "Flame Pokémon")';

CREATE INDEX ix_pokemon_name_search ON pokemon_name (lower(unaccent(display_name)));
CREATE INDEX ix_pokemon_name_sort ON pokemon_name (sort_name);

-- ============================================================================
-- DOMAIN: Move Availability
-- ============================================================================

CREATE TABLE move_availability_type (
  move_availability_type_id serial PRIMARY KEY,
  key                       text NOT NULL UNIQUE,
  sort_order                smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE move_availability_type IS 'How a move can be learned (level_up, elite_tm, legacy, etc.)';

CREATE TABLE pokemon_has_move (
  pokemon_id                int NOT NULL REFERENCES pokemon(pokemon_id) ON DELETE CASCADE,
  move_id                   int NOT NULL REFERENCES move(move_id) ON DELETE CASCADE,
  move_availability_type_id int NOT NULL REFERENCES move_availability_type(move_availability_type_id),
  is_current                boolean NOT NULL DEFAULT true,
  PRIMARY KEY (pokemon_id, move_id, move_availability_type_id)
);

COMMENT ON COLUMN pokemon_has_move.is_current IS 'Whether this move is currently obtainable';

CREATE INDEX ix_pokemon_moves ON pokemon_has_move(pokemon_id);
CREATE INDEX ix_move_pokemon ON pokemon_has_move(move_id);

-- ============================================================================
-- DOMAIN: Community Days
-- ============================================================================

CREATE TABLE cday (
  cday_id       serial PRIMARY KEY,
  key           text NOT NULL UNIQUE,
  date          date NOT NULL,
  featured_pokemon_id int REFERENCES pokemon(pokemon_id),
  sort_order    smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE cday IS 'Community Day events';

CREATE TABLE cday_move (
  cday_id       int NOT NULL REFERENCES cday(cday_id) ON DELETE CASCADE,
  pokemon_id    int NOT NULL REFERENCES pokemon(pokemon_id) ON DELETE CASCADE,
  move_id       int NOT NULL REFERENCES move(move_id) ON DELETE CASCADE,
  PRIMARY KEY (cday_id, pokemon_id, move_id)
);

COMMENT ON TABLE cday_move IS 'Exclusive moves available during Community Days';

-- ============================================================================
-- DOMAIN: Raid Simulations
-- ============================================================================

CREATE TABLE raid_sim_settings (
  raid_sim_settings_id serial PRIMARY KEY,
  key                  text NOT NULL UNIQUE,
  tier                 smallint NOT NULL,
  boss_cp              integer NOT NULL,
  boss_hp              integer NOT NULL,
  time_limit_seconds   integer NOT NULL DEFAULT 180,
  num_raiders          smallint NOT NULL DEFAULT 1,
  friendship_level     text,
  weather_boost_type_id int REFERENCES "type"(type_id),
  description          text
);

COMMENT ON TABLE raid_sim_settings IS 'Raid simulation configuration presets';

CREATE TABLE raid_sort (
  raid_sort_id  serial PRIMARY KEY,
  key           text NOT NULL UNIQUE,
  display_order smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE raid_sort IS 'Raid attacker sorting methods (DPS, TDO, etc.)';

CREATE TABLE raid_rank (
  raid_rank_id          serial PRIMARY KEY,
  raid_sim_settings_id  int NOT NULL REFERENCES raid_sim_settings(raid_sim_settings_id) ON DELETE CASCADE,
  raid_sort_id          int NOT NULL REFERENCES raid_sort(raid_sort_id),
  pokemon_id            int NOT NULL REFERENCES pokemon(pokemon_id),
  fast_move_id          int NOT NULL REFERENCES move(move_id),
  charged_move_id       int NOT NULL REFERENCES move(move_id),
  rank                  smallint NOT NULL,
  metric_value          numeric(10,2),
  UNIQUE (raid_sim_settings_id, raid_sort_id, rank)
);

COMMENT ON TABLE raid_rank IS 'Raid attacker rankings per simulation settings';
COMMENT ON COLUMN raid_rank.metric_value IS 'DPS, TDO, or other metric value';

CREATE INDEX ix_raid_rank_settings ON raid_rank(raid_sim_settings_id, raid_sort_id);
CREATE INDEX ix_raid_rank_pokemon ON raid_rank(pokemon_id);

-- ============================================================================
-- DOMAIN: PvP Leagues
-- ============================================================================

CREATE TABLE league (
  league_id   serial PRIMARY KEY,
  key         text NOT NULL UNIQUE,
  cp_limit    integer,
  sort_order  smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE league IS 'PvP leagues (great, ultra, master, etc.)';
COMMENT ON COLUMN league.cp_limit IS 'CP cap for the league (NULL = unlimited)';

CREATE TABLE league_name (
  league_id     int NOT NULL REFERENCES league(league_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  PRIMARY KEY (league_id, language_id)
);

-- ============================================================================
-- DOMAIN: PvP Rankings
-- ============================================================================

CREATE TABLE pvp_sort_group (
  pvp_sort_group_id serial PRIMARY KEY,
  key               text NOT NULL UNIQUE,
  description       text
);

COMMENT ON TABLE pvp_sort_group IS 'PvP sorting categories (overall, leads, closers, etc.)';

CREATE TABLE pvp_sort (
  pvp_sort_id       serial PRIMARY KEY,
  pvp_sort_group_id int NOT NULL REFERENCES pvp_sort_group(pvp_sort_group_id),
  key               text NOT NULL UNIQUE,
  display_order     smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE pvp_sort IS 'PvP sorting methods within groups';

CREATE TABLE pvp_rank (
  pvp_rank_id     serial PRIMARY KEY,
  league_id       int NOT NULL REFERENCES league(league_id),
  pvp_sort_id     int NOT NULL REFERENCES pvp_sort(pvp_sort_id),
  pokemon_id      int NOT NULL REFERENCES pokemon(pokemon_id),
  fast_move_id    int NOT NULL REFERENCES move(move_id),
  charged_move1_id int NOT NULL REFERENCES move(move_id),
  charged_move2_id int REFERENCES move(move_id),
  rank            smallint NOT NULL,
  rating          numeric(6,2),
  UNIQUE (league_id, pvp_sort_id, rank)
);

COMMENT ON TABLE pvp_rank IS 'PvP Pokémon rankings per league and sort method';

CREATE INDEX ix_pvp_rank_league ON pvp_rank(league_id, pvp_sort_id);
CREATE INDEX ix_pvp_rank_pokemon ON pvp_rank(pokemon_id);

-- ============================================================================
-- DOMAIN: Custom Fields (Extensibility)
-- ============================================================================

CREATE TABLE field (
  field_id    serial PRIMARY KEY,
  key         text NOT NULL UNIQUE,
  data_type   text NOT NULL,
  entity_type text NOT NULL,
  sort_order  smallint NOT NULL DEFAULT 0
);

COMMENT ON TABLE field IS 'Custom/dynamic field definitions for extensibility';
COMMENT ON COLUMN field.data_type IS 'Field data type (text, integer, boolean, etc.)';
COMMENT ON COLUMN field.entity_type IS 'Entity this field applies to (pokemon, move, etc.)';

CREATE TABLE field_name (
  field_id      int NOT NULL REFERENCES field(field_id) ON DELETE CASCADE,
  language_id   int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name  text NOT NULL,
  description   text,
  PRIMARY KEY (field_id, language_id)
);

-- ============================================================================
-- DOMAIN: Stat Multipliers (CP Calculation)
-- ============================================================================

CREATE TABLE stat_multiplier (
  level         numeric(4,1) PRIMARY KEY,
  multiplier    numeric(10,8) NOT NULL
);

COMMENT ON TABLE stat_multiplier IS 'CP multipliers per level for CP calculation';
COMMENT ON COLUMN stat_multiplier.level IS 'Pokémon level (1.0 to 50.0)';

-- ============================================================================
-- SEARCH: Token System for Flexible Search
-- ============================================================================

CREATE TYPE token_domain AS ENUM (
  'pokemon',
  'move', 
  'type',
  'region',
  'weather',
  'operator',
  'tag'
);

CREATE TABLE search_token (
  token_id     serial PRIMARY KEY,
  language_id  int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  domain       token_domain NOT NULL,
  token        text NOT NULL,
  normalized   text GENERATED ALWAYS AS (lower(unaccent(token))) STORED,
  priority     smallint NOT NULL DEFAULT 0,
  is_official  boolean NOT NULL DEFAULT false,
  UNIQUE (language_id, domain, normalized)
);

COMMENT ON TABLE search_token IS 'Search tokens/aliases for fuzzy and flexible searching';
COMMENT ON COLUMN search_token.normalized IS 'Normalized token for case/accent-insensitive search';
COMMENT ON COLUMN search_token.priority IS 'Higher priority tokens appear first in results';
COMMENT ON COLUMN search_token.is_official IS 'Official name vs. alias/synonym';

CREATE INDEX ix_search_token_normalized ON search_token USING gin(normalized gin_trgm_ops);
CREATE INDEX ix_search_token_domain ON search_token(language_id, domain);

-- Token reference tables
CREATE TABLE search_token_ref_pokemon (
  token_id   int NOT NULL REFERENCES search_token(token_id) ON DELETE CASCADE,
  pokemon_id int NOT NULL REFERENCES pokemon(pokemon_id) ON DELETE CASCADE,
  PRIMARY KEY (token_id, pokemon_id)
);

CREATE TABLE search_token_ref_move (
  token_id int NOT NULL REFERENCES search_token(token_id) ON DELETE CASCADE,
  move_id  int NOT NULL REFERENCES move(move_id) ON DELETE CASCADE,
  PRIMARY KEY (token_id, move_id)
);

CREATE TABLE search_token_ref_type (
  token_id int NOT NULL REFERENCES search_token(token_id) ON DELETE CASCADE,
  type_id  int NOT NULL REFERENCES "type"(type_id) ON DELETE CASCADE,
  PRIMARY KEY (token_id, type_id)
);

CREATE TABLE search_token_ref_region (
  token_id  int NOT NULL REFERENCES search_token(token_id) ON DELETE CASCADE,
  region_id int NOT NULL REFERENCES region(region_id) ON DELETE CASCADE,
  PRIMARY KEY (token_id, region_id)
);

-- ============================================================================
-- SEARCH: Operators for Advanced Queries
-- ============================================================================

CREATE TABLE search_operator (
  operator_key text PRIMARY KEY,
  param_kind   text NOT NULL CHECK (
    param_kind IN (
      'none', 'text', 'number', 'boolean', 
      'type', 'region', 'pokemon', 'move'
    )
  ),
  description  text
);

COMMENT ON TABLE search_operator IS 'Search operators (shiny, evolve, @type, etc.)';
COMMENT ON COLUMN search_operator.param_kind IS 'Parameter type expected by operator';

CREATE TABLE search_operator_token (
  operator_key text NOT NULL REFERENCES search_operator(operator_key) ON DELETE CASCADE,
  language_id  int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  token        text NOT NULL,
  normalized   text GENERATED ALWAYS AS (lower(unaccent(token))) STORED,
  PRIMARY KEY (operator_key, language_id, normalized)
);

COMMENT ON TABLE search_operator_token IS 'Localized operator strings';

CREATE INDEX ix_search_operator_token_norm ON search_operator_token(normalized);

-- ============================================================================
-- I18N: Generic UI Strings (Optional)
-- ============================================================================

CREATE TABLE i18n_string (
  key         text NOT NULL,
  language_id int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  value       text NOT NULL,
  context     text,
  PRIMARY KEY (key, language_id)
);

COMMENT ON TABLE i18n_string IS 'Generic UI string translations (buttons, labels, messages)';
COMMENT ON COLUMN i18n_string.context IS 'Usage context for translators';

CREATE INDEX ix_i18n_string_key ON i18n_string(key);

-- ============================================================================
-- EXTENSIONS: Enable Required PostgreSQL Extensions
-- ============================================================================

-- Unaccent for accent-insensitive search
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Trigram for fuzzy string matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- VIEWS: Common Query Patterns
-- ============================================================================

-- Pokémon with localized names and types
CREATE OR REPLACE VIEW v_pokemon_localized AS
SELECT 
  p.pokemon_id,
  p.dex_no,
  p.slug,
  pn.language_id,
  l.code AS language_code,
  pn.display_name AS pokemon_name,
  pn.genus,
  t1.key AS type1_key,
  t1n.display_name AS type1_name,
  t2.key AS type2_key,
  t2n.display_name AS type2_name,
  r.key AS region_key,
  rn.display_name AS region_name,
  p.is_legendary,
  p.is_mythical,
  p.is_released
FROM pokemon p
JOIN pokemon_name pn ON p.pokemon_id = pn.pokemon_id
JOIN language l ON pn.language_id = l.language_id
JOIN "type" t1 ON p.type1_id = t1.type_id
JOIN type_name t1n ON t1.type_id = t1n.type_id AND pn.language_id = t1n.language_id
LEFT JOIN "type" t2 ON p.type2_id = t2.type_id
LEFT JOIN type_name t2n ON t2.type_id = t2n.type_id AND pn.language_id = t2n.language_id
LEFT JOIN region r ON p.region_id = r.region_id
LEFT JOIN region_name rn ON r.region_id = rn.region_id AND pn.language_id = rn.language_id;

COMMENT ON VIEW v_pokemon_localized IS 'Pokémon with all localized names';

-- ============================================================================
-- FUNCTIONS: Helper Functions
-- ============================================================================

-- Get localized name with fallback to default language
CREATE OR REPLACE FUNCTION get_pokemon_name(
  p_pokemon_id int,
  p_language_code text
) RETURNS text AS $$
  SELECT COALESCE(
    (SELECT display_name FROM pokemon_name pn
     JOIN language l ON l.language_id = pn.language_id
     WHERE pn.pokemon_id = p_pokemon_id AND l.code = p_language_code),
    (SELECT display_name FROM pokemon_name pn
     JOIN language l ON l.language_id = pn.language_id
     WHERE pn.pokemon_id = p_pokemon_id AND l.is_default = true)
  );
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION get_pokemon_name IS 'Get Pokémon name with language fallback';

-- Calculate CP
CREATE OR REPLACE FUNCTION calculate_cp(
  p_attack int,
  p_defense int,
  p_stamina int,
  p_level numeric,
  p_iv_attack int DEFAULT 15,
  p_iv_defense int DEFAULT 15,
  p_iv_stamina int DEFAULT 15
) RETURNS int AS $$
DECLARE
  v_multiplier numeric;
  v_cp numeric;
BEGIN
  SELECT multiplier INTO v_multiplier FROM stat_multiplier WHERE level = p_level;
  
  IF v_multiplier IS NULL THEN
    RETURN NULL;
  END IF;
  
  v_cp := (p_attack + p_iv_attack) * 
          SQRT(p_defense + p_iv_defense) * 
          SQRT(p_stamina + p_iv_stamina) * 
          POWER(v_multiplier, 2) / 10.0;
  
  RETURN GREATEST(FLOOR(v_cp), 10);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_cp IS 'Calculate CP for given stats, level, and IVs';

-- ============================================================================
-- SAMPLE DATA: Default Language
-- ============================================================================

INSERT INTO language (code, name, is_default) VALUES 
  ('en', 'English', true),
  ('de', 'Deutsch', false),
  ('ja', '日本語', false),
  ('fr', 'Français', false),
  ('es', 'Español', false)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- End of Schema
-- ============================================================================
