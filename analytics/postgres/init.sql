-- Ultraball analytics schema
-- Runs once on first container boot (Docker entrypoint-initdb.d convention).

CREATE TABLE IF NOT EXISTS games (
    id            SERIAL PRIMARY KEY,
    recorded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    home_team     TEXT NOT NULL,
    away_team     TEXT NOT NULL,
    home_score    INTEGER NOT NULL DEFAULT 0,
    away_score    INTEGER NOT NULL DEFAULT 0,
    winner        TEXT NOT NULL,          -- 'home' | 'away' | 'draw'
    forfeit       BOOLEAN NOT NULL DEFAULT FALSE,
    acts_played   INTEGER NOT NULL DEFAULT 1,
    ai_strategy   TEXT NOT NULL DEFAULT '',
    ai_tactics    TEXT NOT NULL DEFAULT '',
    total_ability_uses INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ability_uses (
    id                  BIGSERIAL PRIMARY KEY,
    game_id             INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    recorded_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    player_id           TEXT NOT NULL,
    player_name         TEXT NOT NULL,
    player_class        TEXT NOT NULL,
    team                TEXT NOT NULL,    -- 'player' | 'opponent'
    slot                SMALLINT NOT NULL,
    ability_name        TEXT NOT NULL,
    damage_dealt        REAL NOT NULL DEFAULT 0,
    caused_fumble       BOOLEAN NOT NULL DEFAULT FALSE,
    applied_cc          BOOLEAN NOT NULL DEFAULT FALSE,
    hit_a_target        BOOLEAN NOT NULL DEFAULT FALSE,
    team_had_ball       BOOLEAN NOT NULL DEFAULT FALSE,
    player_hp_ratio     REAL NOT NULL DEFAULT 1,
    game_time_remaining REAL NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_au_class       ON ability_uses (player_class);
CREATE INDEX IF NOT EXISTS idx_au_ability     ON ability_uses (ability_name);
CREATE INDEX IF NOT EXISTS idx_au_game        ON ability_uses (game_id);
CREATE INDEX IF NOT EXISTS idx_au_recorded    ON ability_uses (recorded_at);
CREATE INDEX IF NOT EXISTS idx_games_recorded ON games (recorded_at);
