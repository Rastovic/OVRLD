/// Schema v1. Every later change is an additive migration in [migrate]; a
/// backup made by an older version must always restore into a newer one.
const schemaVersion = 2;

const createStatements = [
  '''CREATE TABLE profile (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    name TEXT NOT NULL DEFAULT '',
    birth_date TEXT,
    sex TEXT,
    height_cm REAL,
    goal TEXT NOT NULL DEFAULT 'muscle',
    experience TEXT NOT NULL DEFAULT 'intermediate',
    weight_unit TEXT NOT NULL DEFAULT 'kg',
    distance_unit TEXT NOT NULL DEFAULT 'km',
    height_unit TEXT NOT NULL DEFAULT 'cm',
    rest_default_s INTEGER NOT NULL DEFAULT 90,
    onboarded INTEGER NOT NULL DEFAULT 0,
    tour_seen INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE body_weight (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    kg REAL NOT NULL
  )''',
  '''CREATE TABLE split_tag (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    color INTEGER NOT NULL,
    sort INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE exercise (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    muscle TEXT NOT NULL,
    equipment TEXT NOT NULL,
    kind TEXT NOT NULL,
    increment_kg REAL NOT NULL DEFAULT 2.5,
    archived INTEGER NOT NULL DEFAULT 0,
    custom INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE template (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    split_id INTEGER,
    archived INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE template_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL,
    exercise_id INTEGER NOT NULL,
    pos INTEGER NOT NULL,
    sets INTEGER NOT NULL,
    rep_min INTEGER NOT NULL,
    rep_max INTEGER NOT NULL,
    rest_s INTEGER,
    grp INTEGER
  )''',
  '''CREATE TABLE plan (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 0,
    started_on TEXT NOT NULL
  )''',
  '''CREATE TABLE plan_day (
    plan_id INTEGER NOT NULL,
    weekday INTEGER NOT NULL,
    kind TEXT NOT NULL,
    template_id INTEGER,
    cardio TEXT,
    note TEXT,
    PRIMARY KEY (plan_id, weekday)
  )''',
  '''CREATE TABLE session (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER,
    split_id INTEGER,
    name TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    energy INTEGER,
    feel INTEGER,
    note TEXT,
    off_plan INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE session_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    exercise_id INTEGER NOT NULL,
    pos INTEGER NOT NULL,
    grp INTEGER,
    sets_planned INTEGER NOT NULL,
    rep_min INTEGER NOT NULL,
    rep_max INTEGER NOT NULL,
    rest_s INTEGER
  )''',
  '''CREATE TABLE set_entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL,
    idx INTEGER NOT NULL,
    kg REAL NOT NULL,
    reps INTEGER NOT NULL,
    seconds INTEGER,
    rpe REAL,
    warmup INTEGER NOT NULL DEFAULT 0,
    done_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE cardio (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    duration_s INTEGER NOT NULL,
    distance_m REAL NOT NULL DEFAULT 0,
    avg_hr INTEGER,
    energy INTEGER,
    note TEXT
  )''',
  'CREATE INDEX idx_item_session ON session_item(session_id)',
  'CREATE INDEX idx_item_exercise ON session_item(exercise_id)',
  'CREATE INDEX idx_set_item ON set_entry(item_id)',
  'CREATE INDEX idx_session_started ON session(started_at)',
  'CREATE INDEX idx_cardio_started ON cardio(started_at)',
];

/// Additive steps from [from] up to [schemaVersion]. Never rewrite or drop.
const migrations = <int, List<String>>{
  // v2: the first-run walkthrough has been seen.
  2: ['ALTER TABLE profile ADD COLUMN tour_seen INTEGER NOT NULL DEFAULT 0'],
};

/// Tables in dependency order. Backup writes them in this order and restore
/// replaces them in this order.
const allTables = [
  'profile', 'body_weight', 'split_tag', 'exercise', 'template', 'template_item',
  'plan', 'plan_day', 'session', 'session_item', 'set_entry', 'cardio',
];
