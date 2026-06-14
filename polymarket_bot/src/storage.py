"""SQLite persistence via SQLAlchemy 2.x."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    Integer,
    String,
    Text,
    create_engine,
    select,
    update,
)
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings


class Base(DeclarativeBase):
    pass


class MarketRecord(Base):
    __tablename__ = "markets"

    id = Column(Integer, primary_key=True, autoincrement=True)
    condition_id = Column(String(128), unique=True, nullable=False, index=True)
    question = Column(Text, nullable=False)
    category = Column(String(128), nullable=True)
    end_date = Column(DateTime, nullable=True)
    volume = Column(Float, default=0.0)
    liquidity = Column(Float, default=0.0)
    active = Column(Boolean, default=True)
    clob_token_ids = Column(Text, nullable=True)  # JSON array
    outcome_prices = Column(Text, nullable=True)   # JSON array
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class SignalRecord(Base):
    __tablename__ = "signals"

    id = Column(Integer, primary_key=True, autoincrement=True)
    condition_id = Column(String(128), nullable=False, index=True)
    question = Column(Text, nullable=False)
    outcome = Column(String(8), nullable=False)   # YES / NO
    signal_type = Column(String(16), nullable=False)  # BUY / SELL / HOLD
    price = Column(Float, nullable=False)
    spread = Column(Float, nullable=True)
    liquidity = Column(Float, nullable=True)
    reason = Column(Text, nullable=True)
    approved = Column(Boolean, default=False)
    rejection_reason = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class OrderRecord(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, autoincrement=True)
    condition_id = Column(String(128), nullable=False, index=True)
    question = Column(Text, nullable=False)
    outcome = Column(String(8), nullable=False)
    side = Column(String(4), nullable=False)   # BUY / SELL
    price = Column(Float, nullable=False)
    quantity = Column(Float, nullable=False)
    usdc_value = Column(Float, nullable=False)
    slippage_usdc = Column(Float, default=0.0)
    status = Column(String(16), default="FILLED")  # FILLED / CANCELLED
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class PositionRecord(Base):
    __tablename__ = "positions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    condition_id = Column(String(128), nullable=False, index=True)
    question = Column(Text, nullable=False)
    outcome = Column(String(8), nullable=False)
    avg_entry_price = Column(Float, nullable=False)
    current_price = Column(Float, nullable=False)
    quantity = Column(Float, nullable=False)
    cost_basis = Column(Float, nullable=False)
    current_value = Column(Float, nullable=False)
    unrealized_pnl = Column(Float, default=0.0)
    realized_pnl = Column(Float, default=0.0)
    status = Column(String(8), default="OPEN")  # OPEN / CLOSED
    close_reason = Column(String(32), nullable=True)
    opened_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    closed_at = Column(DateTime, nullable=True)


class SnapshotRecord(Base):
    __tablename__ = "portfolio_snapshots"

    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    balance = Column(Float, nullable=False)
    equity = Column(Float, nullable=False)
    total_pnl = Column(Float, default=0.0)
    realized_pnl = Column(Float, default=0.0)
    unrealized_pnl = Column(Float, default=0.0)
    open_positions = Column(Integer, default=0)
    total_trades = Column(Integer, default=0)
    winning_trades = Column(Integer, default=0)
    drawdown = Column(Float, default=0.0)
    peak_equity = Column(Float, nullable=False)


class Storage:
    def __init__(self, database_url: str | None = None) -> None:
        url = database_url or get_settings().database_url
        # Ensure sqlite file directory exists
        if url.startswith("sqlite:///"):
            db_path = Path(url.replace("sqlite:///", ""))
            db_path.parent.mkdir(parents=True, exist_ok=True)
        self.engine = create_engine(url, connect_args={"check_same_thread": False})
        Base.metadata.create_all(self.engine)
        self._Session = sessionmaker(bind=self.engine)

    def session(self) -> Session:
        return self._Session()

    # ── Markets ──────────────────────────────────────────────────────────────

    def upsert_market(self, data: dict[str, Any]) -> MarketRecord:
        with self.session() as s:
            rec = s.scalar(
                select(MarketRecord).where(
                    MarketRecord.condition_id == data["condition_id"]
                )
            )
            if rec:
                for k, v in data.items():
                    if hasattr(rec, k):
                        setattr(rec, k, v)
                rec.updated_at = datetime.now(timezone.utc)
            else:
                rec = MarketRecord(**{k: v for k, v in data.items() if hasattr(MarketRecord, k)})
                s.add(rec)
            s.commit()
            s.refresh(rec)
            return rec

    def get_markets(self, active_only: bool = True) -> list[MarketRecord]:
        with self.session() as s:
            q = select(MarketRecord)
            if active_only:
                q = q.where(MarketRecord.active == True)  # noqa: E712
            return list(s.scalars(q).all())

    # ── Signals ──────────────────────────────────────────────────────────────

    def save_signal(self, data: dict[str, Any]) -> SignalRecord:
        with self.session() as s:
            rec = SignalRecord(**{k: v for k, v in data.items() if hasattr(SignalRecord, k)})
            s.add(rec)
            s.commit()
            s.refresh(rec)
            return rec

    def get_signals(self, limit: int = 200) -> list[SignalRecord]:
        with self.session() as s:
            q = select(SignalRecord).order_by(SignalRecord.created_at.desc()).limit(limit)
            return list(s.scalars(q).all())

    # ── Orders ───────────────────────────────────────────────────────────────

    def save_order(self, data: dict[str, Any]) -> OrderRecord:
        with self.session() as s:
            rec = OrderRecord(**{k: v for k, v in data.items() if hasattr(OrderRecord, k)})
            s.add(rec)
            s.commit()
            s.refresh(rec)
            return rec

    def get_orders(self, limit: int = 500) -> list[OrderRecord]:
        with self.session() as s:
            q = select(OrderRecord).order_by(OrderRecord.created_at.desc()).limit(limit)
            return list(s.scalars(q).all())

    # ── Positions ─────────────────────────────────────────────────────────────

    def save_position(self, data: dict[str, Any]) -> PositionRecord:
        with self.session() as s:
            rec = PositionRecord(**{k: v for k, v in data.items() if hasattr(PositionRecord, k)})
            s.add(rec)
            s.commit()
            s.refresh(rec)
            return rec

    def get_open_positions(self) -> list[PositionRecord]:
        with self.session() as s:
            q = select(PositionRecord).where(PositionRecord.status == "OPEN")
            return list(s.scalars(q).all())

    def get_all_positions(self) -> list[PositionRecord]:
        with self.session() as s:
            return list(s.scalars(select(PositionRecord).order_by(PositionRecord.opened_at.desc())).all())

    def update_position(self, position_id: int, data: dict[str, Any]) -> None:
        with self.session() as s:
            s.execute(
                update(PositionRecord)
                .where(PositionRecord.id == position_id)
                .values(**{k: v for k, v in data.items() if hasattr(PositionRecord, k)})
            )
            s.commit()

    def get_open_position_by_market(
        self, condition_id: str, outcome: str
    ) -> PositionRecord | None:
        with self.session() as s:
            return s.scalar(
                select(PositionRecord).where(
                    PositionRecord.condition_id == condition_id,
                    PositionRecord.outcome == outcome,
                    PositionRecord.status == "OPEN",
                )
            )

    # ── Snapshots ────────────────────────────────────────────────────────────

    def save_snapshot(self, data: dict[str, Any]) -> SnapshotRecord:
        with self.session() as s:
            rec = SnapshotRecord(**{k: v for k, v in data.items() if hasattr(SnapshotRecord, k)})
            s.add(rec)
            s.commit()
            s.refresh(rec)
            return rec

    def get_snapshots(self, limit: int = 1000) -> list[SnapshotRecord]:
        with self.session() as s:
            q = (
                select(SnapshotRecord)
                .order_by(SnapshotRecord.timestamp.asc())
                .limit(limit)
            )
            return list(s.scalars(q).all())

    def get_latest_snapshot(self) -> SnapshotRecord | None:
        with self.session() as s:
            return s.scalar(
                select(SnapshotRecord).order_by(SnapshotRecord.timestamp.desc()).limit(1)
            )

    # ── Reset ─────────────────────────────────────────────────────────────────

    def reset_paper_trading(self) -> None:
        """Delete all paper trading state (orders, positions, snapshots, signals)."""
        with self.session() as s:
            s.query(OrderRecord).delete()
            s.query(PositionRecord).delete()
            s.query(SnapshotRecord).delete()
            s.query(SignalRecord).delete()
            s.commit()
