"""
Ultraball Analytics API — receives game reports from the Flutter web app
and writes them to PostgreSQL for Grafana to visualize.
"""

from __future__ import annotations

import os
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://ub:ub@localhost:5432/ultraball",
)

_pool: asyncpg.Pool | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _pool
    _pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=5)
    yield
    if _pool:
        await _pool.close()


app = FastAPI(title="Ultraball Analytics", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    # Allow requests from the Flutter dev server (any localhost port)
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)


# ── Pydantic models ────────────────────────────────────────────────────────────

class AbilityUse(BaseModel):
    player_id: str
    player_name: str
    player_class: str
    team: str
    slot: int
    ability_name: str
    damage_dealt: float
    caused_fumble: bool
    applied_cc: bool
    hit_a_target: bool
    team_had_ball: bool
    player_hp_ratio: float
    game_time_remaining: float


class GameReport(BaseModel):
    home_team: str
    away_team: str
    home_score: int
    away_score: int
    winner: str               # 'home' | 'away' | 'draw'
    forfeit: bool
    acts_played: int
    ai_strategy: str
    ai_tactics: str
    ability_uses: list[AbilityUse]


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    try:
        async with _pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return {"status": "ok"}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@app.post("/report", status_code=201)
async def submit_report(report: GameReport):
    if _pool is None:
        raise HTTPException(status_code=503, detail="database pool not ready")

    try:
        async with _pool.acquire() as conn:
            async with conn.transaction():
                game_id = await conn.fetchval(
                    """
                    INSERT INTO games (
                        home_team, away_team, home_score, away_score,
                        winner, forfeit, acts_played,
                        ai_strategy, ai_tactics, total_ability_uses
                    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
                    RETURNING id
                    """,
                    report.home_team, report.away_team,
                    report.home_score, report.away_score,
                    report.winner, report.forfeit, report.acts_played,
                    report.ai_strategy, report.ai_tactics,
                    len(report.ability_uses),
                )

                if report.ability_uses:
                    await conn.executemany(
                        """
                        INSERT INTO ability_uses (
                            game_id, player_id, player_name, player_class, team,
                            slot, ability_name, damage_dealt, caused_fumble,
                            applied_cc, hit_a_target, team_had_ball,
                            player_hp_ratio, game_time_remaining
                        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
                        """,
                        [
                            (
                                game_id,
                                u.player_id, u.player_name, u.player_class, u.team,
                                u.slot, u.ability_name, u.damage_dealt,
                                u.caused_fumble, u.applied_cc, u.hit_a_target,
                                u.team_had_ball, u.player_hp_ratio,
                                u.game_time_remaining,
                            )
                            for u in report.ability_uses
                        ],
                    )

        return {"game_id": game_id, "uses_written": len(report.ability_uses)}

    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
