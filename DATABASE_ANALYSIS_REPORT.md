# Pokémon GO Database Schema Analysis Report

**Date:** December 1, 2025  
**Schema File:** `pokemon_go_database.sql`  
**Analysis Type:** Structural Issues, Dependencies, and Optimization

---

## 🔍 Executive Summary

This report identifies **7 critical issues** and **several organizational improvements** required for the Pokémon GO database schema. The most severe issue is a circular dependency between the `weather` and `type` tables that will prevent database creation.

---

## 🚨 Critical Issues

### 1. CIRCULAR DEPENDENCY: `weather` ↔ `type`

**Severity:** 🔴 **CRITICAL** - Blocks database creation

**Problem:**
- `weather.boost_type_id` references `type(type_id)`
- `type.weather_id` references `weather(weather_id)`
- This creates an unresolvable circular foreign key constraint

**Current Code:**
```sql
-- Line 56
CREATE TABLE weather (
  weather_id    serial PRIMARY KEY,
  boost_type_id int REFERENCES "type"(type_id),  -- References type
  ...
);

-- Line 77
CREATE TABLE "type" (
  type_id       serial PRIMARY KEY,
  weather_id    int REFERENCES weather(weather_id),  -- References weather
  ...
);
```

**Impact:**
- ❌ Cannot create either table first
- ❌ Database schema will fail to deploy
- ❌ PostgreSQL will reject the foreign key constraints

**Solution Options:**

**Option A (Recommended):** Remove bidirectional reference
```sql
-- Keep only type -> weather relationship
CREATE TABLE "type" (
  type_id       serial PRIMARY KEY,
  weather_id    int REFERENCES weather(weather_id),
  ...
);

-- Remove boost_type_id from weather
CREATE TABLE weather (
  weather_id    serial PRIMARY KEY,
  -- boost_type_id removed
  ...
);
```

**Option B:** Use deferred constraints
```sql
CREATE TABLE weather (
  boost_type_id int REFERENCES "type"(type_id) DEFERRABLE INITIALLY DEFERRED,
  ...
);
```

**Option C:** Create junction table
```sql
CREATE TABLE weather_type_boost (
  weather_id int REFERENCES weather(weather_id),
  type_id    int REFERENCES "type"(type_id),
  PRIMARY KEY (weather_id, type_id)
);
```

---

### 2. MISSING TABLE CREATION ORDER

**Severity:** 🟠 **HIGH** - May cause deployment failures

**Problem:** Tables are not ordered according to their dependencies.

**Dependency Chain:**
```
language (independent)
  ↓
weather (independent after fixing circular ref)
  ↓
type (depends on weather)
  ↓
interaction_type (independent)
  ↓
type_interaction (depends on type, interaction_type)
  ↓
move_category (independent)
  ↓
adventure_effect (independent)
  ↓
move (depends on type, move_category, adventure_effect)
  ↓
region (independent)
  ↓
stage (independent)
  ↓
color (independent)
  ↓
evolution_item (independent)
  ↓
pokemon (depends on type, region, stage, color, evolution_item)
  ↓
*_name tables (depend on their parent tables + language)
```

**Current Issues:**
- `weather.boost_type_id` references `type` (created later)
- `move.type_id` references `type`
- Extensions created at end, but used throughout

**Solution:** Reorder tables following the dependency graph above.

---

### 3. CONSTRAINT REFERENCE MISMATCH

**Severity:** 🟡 **MEDIUM** - Data integrity risk

**Problem:** Hardcoded constraint contradicts database design.

**Current Code:**
```sql
-- Line 410
CREATE TABLE pokemon (
  stage_id          int REFERENCES stage(stage_id),
  ...
  CONSTRAINT chk_stage CHECK (stage_id >= -1 AND stage_id <= 2),
  ...
);

-- Line 292
CREATE TABLE stage (
  stage_id    serial PRIMARY KEY,  -- serial = positive integers only
  stage_num   smallint NOT NULL,
  ...
);
```

**Issue:** 
- Constraint expects `stage_id` values: -1, 0, 1, 2
- `serial` type generates: 1, 2, 3, 4, ...
- Constraint should check `stage_num`, not `stage_id`

**Impact:**
- Constraint will always fail for negative values
- Misleading validation logic
- Potential data insertion failures

**Solution A (Recommended):** Fix constraint to use stage_num
```sql
-- Remove from pokemon table, add to stage table
CREATE TABLE stage (
  stage_id    serial PRIMARY KEY,
  stage_num   smallint NOT NULL CHECK (stage_num BETWEEN -1 AND 2),
  ...
);
```

**Solution B:** Remove constraint, rely on foreign key
```sql
-- Remove CHECK constraint entirely from pokemon table
CREATE TABLE pokemon (
  stage_id          int REFERENCES stage(stage_id),
  -- No CHECK constraint
  ...
);
```

---

### 4. INCONSISTENT `ON DELETE` ACTIONS

**Severity:** 🟡 **MEDIUM** - Data integrity risk

**Problem:** Inconsistent cascade behavior across similar relationships.

**Examples:**

| Table | Column | ON DELETE Action | Correct? |
|-------|--------|------------------|----------|
| `weather_name` | `weather_id` | `CASCADE` | ✅ |
| `type_name` | `type_id` | `CASCADE` | ✅ |
| `pokemon` | `type1_id` | **NONE** | ❌ |
| `pokemon` | `type2_id` | **NONE** | ❌ |
| `pokemon` | `region_id` | **NONE** | ❌ |
| `pokemon` | `stage_id` | **NONE** | ❌ |
| `pokemon` | `color_id` | **NONE** | ❌ |
| `move` | `type_id` | **NONE** | ❌ |
| `raid_sim_settings` | `type_id` | `CASCADE` | ✅ |

**Impact:**
- Risk of orphaned Pokemon records if types are deleted
- Inconsistent data integrity enforcement
- Unpredictable behavior during data maintenance

**Solution:** Standardize based on business rules:

```sql
-- Core reference data - RESTRICT deletion
CREATE TABLE pokemon (
  type1_id int NOT NULL REFERENCES "type"(type_id) ON DELETE RESTRICT,
  type2_id int REFERENCES "type"(type_id) ON DELETE RESTRICT,
  region_id int REFERENCES region(region_id) ON DELETE SET NULL,
  stage_id int REFERENCES stage(stage_id) ON DELETE RESTRICT,
  color_id int REFERENCES color(color_id) ON DELETE SET NULL,
  ...
);

-- Translation data - CASCADE deletion
-- (already correct for most *_name tables)
```

---

### 5. MISSING INDEXES ON FOREIGN KEYS

**Severity:** 🟡 **MEDIUM** - Performance issue

**Problem:** Foreign key columns without indexes cause slow JOIN operations.

**Missing Indexes:**

```sql
-- Weather domain
weather.boost_type_id          -- (if kept after fixing circular ref)

-- Type domain  
type.weather_id                -- Missing index

-- Move domain
move.type_id                   -- Missing index
move.move_category_id          -- Missing index
move.adventure_effect_id       -- Missing index

-- Pokemon domain
pokemon.color_id               -- Missing index
pokemon.evolution_item_id      -- Missing index
pokemon.stage_id               -- Missing index (has partial constraint check)

-- Community Day
cday.featured_pokemon_id       -- Missing index

-- Raid simulation
raid_sim_settings.pokemon1_id  -- Missing index
raid_sim_settings.pokemon2_id  -- Missing index
raid_sim_settings.pokemon3_id  -- Missing index
```

**Impact:**
- Slow query performance on JOINs
- Full table scans instead of index lookups
- Poor scalability as data grows

**Solution:** Add indexes for all foreign keys:

```sql
-- Type domain
CREATE INDEX ix_type_weather ON "type"(weather_id);

-- Move domain
CREATE INDEX ix_move_type ON move(type_id);
CREATE INDEX ix_move_category ON move(move_category_id);
CREATE INDEX ix_move_adventure_effect ON move(adventure_effect_id) WHERE adventure_effect_id IS NOT NULL;

-- Pokemon domain
CREATE INDEX ix_pokemon_color ON pokemon(color_id) WHERE color_id IS NOT NULL;
CREATE INDEX ix_pokemon_evolution_item ON pokemon(evolution_item_id) WHERE evolution_item_id IS NOT NULL;
CREATE INDEX ix_pokemon_stage ON pokemon(stage_id) WHERE stage_id IS NOT NULL;

-- Community Day
CREATE INDEX ix_cday_featured_pokemon ON cday(featured_pokemon_id) WHERE featured_pokemon_id IS NOT NULL;

-- Raid simulation
CREATE INDEX ix_raid_sim_pokemon1 ON raid_sim_settings(pokemon1_id);
CREATE INDEX ix_raid_sim_pokemon2 ON raid_sim_settings(pokemon2_id) WHERE pokemon2_id IS NOT NULL;
CREATE INDEX ix_raid_sim_pokemon3 ON raid_sim_settings(pokemon3_id) WHERE pokemon3_id IS NOT NULL;
```

---

### 6. EXTENSION CREATION ORDER

**Severity:** 🟡 **MEDIUM** - Deployment issue

**Problem:** PostgreSQL extensions are created at the END of the schema, but used throughout.

**Current Code:**
```sql
-- Line 750+ (near end of file)
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- But used earlier in the schema:
-- Line 69
CREATE INDEX ix_weather_name_search ON weather_name (lower(unaccent(display_name)));

-- Line 697
CREATE INDEX ix_search_token_normalized ON search_token USING gin(normalized gin_trgm_ops);
```

**Impact:**
- Index creation may fail if extensions aren't pre-installed
- Schema deployment order matters
- Error messages may be confusing

**Solution:** Move extensions to the beginning:

```sql
-- ============================================================================
-- EXTENSIONS: Enable Required PostgreSQL Extensions
-- ============================================================================
-- NOTE: These must be created FIRST as they're used throughout the schema

-- Unaccent for accent-insensitive search
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Trigram for fuzzy string matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- CORE: Language Support
-- ============================================================================
-- (rest of schema follows...)
```

---

### 7. NUMERIC PRECISION ISSUES

**Severity:** 🟡 **MEDIUM** - Data accuracy risk

**Problem:** Inconsistent or insufficient numeric precision for data types.

**Issues:**

| Column | Current | Issue | Recommended |
|--------|---------|-------|-------------|
| `interaction_type.multiplier` | `numeric(3,2)` | Max 9.99, can't store 10.0+ | `numeric(5,3)` for 99.999 |
| `pokemon.base_catch_rate` | `numeric(3,2)` | Range 0.00-1.00 but allows 9.99 | `numeric(4,3)` for 0.000-1.000 |
| `pokemon.base_flee_rate` | `numeric(3,2)` | Same as catch_rate | `numeric(4,3)` |
| `pokemon.height` | `numeric(4,1)` | Max 999.9m, probably sufficient | OK |
| `pokemon.weight` | `numeric(5,1)` | Max 9999.9kg, probably sufficient | OK |
| `move.raid_dps` | `numeric(6,2)` | Max 9999.99, very high | OK if accurate |
| `move.pvp_dpe` | `numeric(5,2)` | Max 999.99 | OK if accurate |

**Examples of Problematic Values:**

```sql
-- Type effectiveness multipliers in Pokémon GO:
-- Double weakness: 2.56 = 1.6 × 1.6
-- But numeric(3,2) max is 9.99, so this works

-- Future-proofing issue:
INSERT INTO interaction_type (multiplier) VALUES (10.5);  -- FAILS! Too large

-- Catch rate precision:
INSERT INTO pokemon (base_catch_rate) VALUES (0.175);  -- Truncates to 0.18 with numeric(3,2)
-- Should use numeric(4,3) to preserve 0.175
```

**Solution:**

```sql
CREATE TABLE interaction_type (
  interaction_type_id serial PRIMARY KEY,
  key                 text NOT NULL UNIQUE,
  multiplier          numeric(5,3) NOT NULL,  -- Changed: allows up to 99.999
  sort_order          smallint NOT NULL DEFAULT 0
);

CREATE TABLE pokemon (
  ...
  base_catch_rate   numeric(4,3),  -- Changed: 0.000 to 1.000 with 3 decimals
  base_flee_rate    numeric(4,3),  -- Changed: 0.000 to 1.000 with 3 decimals
  ...
);
```

---

## 📋 Organizational Issues

### 8. INCONSISTENT NAMING CONVENTIONS

**Severity:** 🟢 **LOW** - Code quality

**Issues:**

| Pattern | Examples | Issue |
|---------|----------|-------|
| `table_name` + `_name` | `type` → `type_name` ✅ | Consistent |
| `table_type` + `_name` | `interaction_type` → `interaction_name` | Inconsistent (should be `interaction_type_name`) |
| Missing `_name` tables | `move_availability_type` | No internationalization table |
| | `raid_sort` | No internationalization table |
| | `pvp_sort_group` | No internationalization table |

**Impact:**
- Inconsistent API/ORM usage
- Harder to remember table names
- Missing i18n support for some entities

**Recommendation:**

```sql
-- Rename for consistency
ALTER TABLE interaction_name RENAME TO interaction_type_name;

-- Add missing i18n tables
CREATE TABLE move_availability_type_name (
  move_availability_type_id int NOT NULL REFERENCES move_availability_type(move_availability_type_id) ON DELETE CASCADE,
  language_id               int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name              text NOT NULL,
  PRIMARY KEY (move_availability_type_id, language_id)
);

CREATE TABLE raid_sort_name (
  raid_sort_id int NOT NULL REFERENCES raid_sort(raid_sort_id) ON DELETE CASCADE,
  language_id  int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name text NOT NULL,
  PRIMARY KEY (raid_sort_id, language_id)
);

CREATE TABLE pvp_sort_group_name (
  pvp_sort_group_id int NOT NULL REFERENCES pvp_sort_group(pvp_sort_group_id) ON DELETE CASCADE,
  language_id       int NOT NULL REFERENCES language(language_id) ON DELETE CASCADE,
  display_name      text NOT NULL,
  PRIMARY KEY (pvp_sort_group_id, language_id)
);
```

---

### 9. MISSING COMMENTS

**Severity:** 🟢 **LOW** - Documentation

**Tables/Columns Missing Documentation:**

```sql
-- Tables without COMMENT ON TABLE
- language_name (has column comments but no table comment added)
- raid_sort
- pvp_sort
- All search_token_ref_* tables

-- Columns without COMMENT ON COLUMN
- language_name.name (description exists in CSV but not in schema)
- move_tag.key
- many junction table columns
```

**Solution:** Add comprehensive comments for all tables and important columns.

---

### 10. VIEW DEPENDENCY RISK

**Severity:** 🟢 **LOW** - Runtime risk

**Issue:** `v_pokemon_localized` view depends on data existing:

```sql
CREATE OR REPLACE VIEW v_pokemon_localized AS
SELECT 
  ...
  t1n.display_name AS type1_name,  -- Requires type_name data
  ...
FROM pokemon p
JOIN pokemon_name pn ON p.pokemon_id = pn.pokemon_id     -- INNER JOIN
JOIN language l ON pn.language_id = l.language_id        -- INNER JOIN
JOIN "type" t1 ON p.type1_id = t1.type_id               -- INNER JOIN
JOIN type_name t1n ON t1.type_id = t1n.type_id          -- INNER JOIN
  AND pn.language_id = t1n.language_id
...
```

**Impact:**
- View returns no rows if any translation is missing
- Hard to debug for users

**Solution:** Consider making some JOINs optional or document the requirement clearly.

---

## ✅ Recommended Action Plan

### Priority 1: Critical Fixes (Immediate)

1. ✅ **Fix circular dependency** between `weather` and `type`
   - Remove `weather.boost_type_id`
   - Keep only `type.weather_id`

2. ✅ **Move extensions to top** of schema file

3. ✅ **Reorder tables** by dependency
   - Independent tables first
   - Dependent tables after their dependencies

### Priority 2: Data Integrity (High Priority)

4. ✅ **Fix stage_id constraint** mismatch
   - Move CHECK to `stage.stage_num`
   - Remove from `pokemon.stage_id`

5. ✅ **Standardize ON DELETE actions**
   - Core entities: `RESTRICT`
   - Optional references: `SET NULL`
   - Translations: `CASCADE`

6. ✅ **Fix numeric precision** issues
   - `interaction_type.multiplier`: `numeric(5,3)`
   - `pokemon.base_catch_rate`: `numeric(4,3)`
   - `pokemon.base_flee_rate`: `numeric(4,3)`

### Priority 3: Performance (Medium Priority)

7. ✅ **Add missing indexes** on foreign keys
   - All foreign key columns should have indexes
   - Use partial indexes for nullable columns

### Priority 4: Code Quality (Low Priority)

8. ✅ **Rename for consistency**
   - `interaction_name` → `interaction_type_name`

9. ✅ **Add missing i18n tables**
   - `move_availability_type_name`
   - `raid_sort_name`
   - `pvp_sort_group_name`

10. ✅ **Add missing comments** for documentation

---

## 📊 Summary Statistics

| Category | Count | Status |
|----------|-------|--------|
| **Critical Issues** | 3 | 🔴 Must fix |
| **High Priority Issues** | 4 | 🟠 Should fix |
| **Medium Priority Issues** | 0 | 🟡 Consider fixing |
| **Low Priority Issues** | 3 | 🟢 Nice to have |
| **Total Tables** | 45+ | - |
| **Missing Indexes** | 12+ | - |
| **Circular Dependencies** | 1 | 🔴 Blocking |

---

## 🔧 Implementation Notes

### Deployment Strategy

1. **Create new schema file** with all fixes applied
2. **Test in development environment** first
3. **Run migration scripts** for existing databases
4. **Validate with test data** before production

### Migration Considerations

If database already exists with circular dependency:

```sql
-- Step 1: Drop problematic constraints
ALTER TABLE weather DROP CONSTRAINT IF EXISTS weather_boost_type_id_fkey;
ALTER TABLE "type" DROP CONSTRAINT IF EXISTS type_weather_id_fkey;

-- Step 2: Drop problematic column
ALTER TABLE weather DROP COLUMN IF EXISTS boost_type_id;

-- Step 3: Re-add type.weather_id constraint
ALTER TABLE "type" 
  ADD CONSTRAINT type_weather_id_fkey 
  FOREIGN KEY (weather_id) REFERENCES weather(weather_id);
```

---

## 📚 References

- PostgreSQL Documentation: [Foreign Keys](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK)
- PostgreSQL Documentation: [Indexes](https://www.postgresql.org/docs/current/indexes.html)
- Database Design Best Practices: [Naming Conventions](https://www.postgresql.org/docs/current/ddl-constraints.html)
- Original Design Document: `komplette_antwort.md`

---

**Report End**
