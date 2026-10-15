-- Referenzschema (SQLite). Laufzeit: SwiftData-Modelle in architecture.md spiegeln diese Tabellen 1:1.
-- Kein Server, ein Nutzer pro Gerät -> keine owner-Spalte, keine Zugriffsregeln nötig (Sandbox des Geräts).
-- Zeiten: INTEGER Unix-Sekunden UTC. Lokaler Kalendertag wird zur Laufzeit mit TimeZone.current abgeleitet.
-- Katalog (regions, skill_lines, stages) ist Seed-Daten aus catalog.json, versioniert, read-only.

PRAGMA foreign_keys = ON;

-- ===== Katalog (gebündelt, read-only) =====
create table catalog_meta (
  version      integer primary key,          -- catalog.json "version"
  imported_at  integer not null
);

create table regions (
  id     text primary key,                   -- 'push','pull','core','legs','shoulders','grip' (eigene Wahl)
  name   text not null,
  sort   integer not null unique
);

create table skill_lines (
  id         text primary key,               -- stabiler Slug, z.B. 'planche'
  region_id  text not null references regions(id) on delete restrict,
  name       text not null,
  sort       integer not null,
  weight     real not null default 1.0 check (weight > 0)   -- Anteil am Regionsgrad
);
create index idx_lines_region on skill_lines(region_id, sort);

create table stages (
  id          text primary key,              -- '<line>.<index>', z.B. 'planche.07'
  line_id     text not null references skill_lines(id) on delete restrict,
  idx         integer not null check (idx >= 1),
  name        text not null,
  metric      text not null check (metric in ('reps','seconds')),
  target      integer not null check (target > 0),           -- Wdh. oder Sekunden zum Abhaken
  difficulty  real not null check (difficulty between 0 and 1), -- normierte Schwierigkeit für Grade
  unique (line_id, idx)
);
create index idx_stages_line on stages(line_id, idx);

-- ===== Nutzerdaten =====
create table set_logs (
  id         text primary key,               -- UUID
  stage_id   text not null references stages(id) on delete restrict,
  value      integer not null check (value > 0 and value <= 10000),
  logged_at  integer not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer                          -- Soft-Delete für Undo und spätere iCloud-Sync
);
create index idx_logs_stage_time on set_logs(stage_id, logged_at) where deleted_at is null;
create index idx_logs_time on set_logs(logged_at) where deleted_at is null;

-- Abgeleitet, jederzeit aus set_logs neu berechenbar (Cache).
create table line_progress (
  line_id               text primary key references skill_lines(id) on delete cascade,
  highest_cleared_idx   integer not null default 0 check (highest_cleared_idx >= 0),
  cleared_at            integer,
  line_grade            integer not null default 0 check (line_grade between 0 and 4), -- 4 Liniengrade, eigene Namen
  updated_at            integer not null
);

-- Einstufungstest: Selbstangabe, getrennt von echten Logs (Grade dürfen beide nutzen, Power nur Logs).
create table assessment_answers (
  line_id      text primary key references skill_lines(id) on delete cascade,
  claimed_idx  integer not null check (claimed_idx >= 0),
  answered_at  integer not null
);

create table rank_snapshots (
  id             text primary key,
  taken_at       integer not null,
  local_day      text not null,               -- 'YYYY-MM-DD' in damaliger Zeitzone
  overall_grade  integer not null check (overall_grade between 1 and 9),
  power_level    integer not null check (power_level >= 0),
  region_grades  text not null,               -- JSON {"push":5,...}
  reason         text not null check (reason in ('assessment','log','daily','recompute')),
  unique (local_day, reason)                  -- max. 1 'daily' pro Tag; 'log' wird pro Tag überschrieben (upsert)
);
create index idx_snap_time on rank_snapshots(taken_at);

create table plans (
  id               text primary key,
  target_region_id text not null references regions(id) on delete restrict,
  created_at       integer not null,
  status           text not null default 'active' check (status in ('active','done','replaced'))
);
create unique index one_active_plan on plans(status) where status = 'active';

create table plan_items (
  id        text primary key,
  plan_id   text not null references plans(id) on delete cascade,
  stage_id  text not null references stages(id) on delete restrict,
  sets      integer not null check (sets between 1 and 10),
  target    integer not null check (target > 0),
  sort      integer not null,
  done_at   integer
);
create index idx_items_plan on plan_items(plan_id, sort);

-- Entitlements kommen von StoreKit 2 (Transaction.currentEntitlements), nicht aus der DB.
-- Optionaler Cache nur fürs schnelle Kaltstart-UI:
create table entitlement_cache (
  product_id   text primary key check (product_id in ('pro.weekly','pro.yearly')),
  expires_at   integer,
  checked_at   integer not null
);
