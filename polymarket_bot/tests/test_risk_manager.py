"""Tests for risk_manager.py"""

import pytest
from unittest.mock import MagicMock, patch
from datetime import datetime, timezone

from src.risk_manager import RiskManager
from src.strategy import Signal, SignalType
from src.storage import Storage, PositionRecord
from src.config import Settings


def make_settings(**kwargs) -> Settings:
    defaults = dict(
        paper_trading=True, live_trading=False,
        initial_paper_balance_usdc=1000.0,
        max_trade_size_usdc=5.0, max_position_size_usdc=25.0,
        max_daily_loss_usdc=20.0, max_open_positions=3,
        max_market_exposure_usdc=25.0, max_total_exposure_usdc=100.0,
        max_spread=0.03, min_liquidity=500.0, min_hours_to_close=24.0,
        exit_hours_before_close=6.0, entry_price_max=0.45,
        take_profit_pct=0.15, stop_loss_pct=0.10, allow_no=False,
        slippage_bps=10, poll_interval_seconds=30, dashboard_refresh_seconds=10,
        database_url="sqlite:///:memory:", log_level="WARNING",
    )
    defaults.update(kwargs)
    return Settings(**defaults)


def make_signal(condition_id="mkt-1", outcome="YES") -> Signal:
    return Signal(
        condition_id=condition_id,
        question="Will X happen?",
        outcome=outcome,
        signal_type=SignalType.BUY,
        price=0.30,
        spread=0.02,
        liquidity=1000.0,
        reason="test",
    )


def make_position(condition_id="mkt-1", outcome="YES", cost_basis=5.0) -> PositionRecord:
    p = PositionRecord()
    p.id = 1
    p.condition_id = condition_id
    p.outcome = outcome
    p.cost_basis = cost_basis
    p.status = "OPEN"
    return p


class TestRiskManager:
    def _make_rm(self, open_positions=None, existing_position=None, **kwargs):
        s = make_settings(**kwargs)
        storage = MagicMock(spec=Storage)
        storage.get_open_positions.return_value = open_positions or []
        storage.get_open_position_by_market.return_value = existing_position
        return RiskManager(storage=storage, settings=s)

    def test_approved_when_all_checks_pass(self):
        rm = self._make_rm()
        decision = rm.evaluate(make_signal(), current_balance=100.0, daily_loss_usdc=0.0)
        assert decision.approved
        assert decision.trade_size_usdc > 0

    def test_rejected_when_daily_loss_exceeded(self):
        rm = self._make_rm(max_daily_loss_usdc=10.0)
        decision = rm.evaluate(make_signal(), current_balance=100.0, daily_loss_usdc=15.0)
        assert not decision.approved
        assert "daily_loss" in decision.reason

    def test_rejected_when_balance_too_low(self):
        rm = self._make_rm(max_trade_size_usdc=10.0)
        decision = rm.evaluate(make_signal(), current_balance=5.0, daily_loss_usdc=0.0)
        assert not decision.approved
        assert "balance" in decision.reason

    def test_rejected_when_max_positions_reached(self):
        positions = [make_position(f"mkt-{i}") for i in range(3)]
        rm = self._make_rm(open_positions=positions, max_open_positions=3)
        decision = rm.evaluate(make_signal(condition_id="mkt-99"), 100.0, 0.0)
        assert not decision.approved
        assert "open positions" in decision.reason

    def test_rejected_when_duplicate_position(self):
        existing = make_position(condition_id="mkt-1", outcome="YES")
        rm = self._make_rm(existing_position=existing)
        decision = rm.evaluate(make_signal(condition_id="mkt-1", outcome="YES"), 100.0, 0.0)
        assert not decision.approved
        assert "already have open" in decision.reason

    def test_rejected_when_market_exposure_exceeded(self):
        positions = [make_position(condition_id="mkt-1", cost_basis=20.0)]
        rm = self._make_rm(open_positions=positions, max_market_exposure_usdc=20.0)
        decision = rm.evaluate(make_signal(condition_id="mkt-1"), 100.0, 0.0)
        assert not decision.approved
        assert "market exposure" in decision.reason

    def test_rejected_when_total_exposure_exceeded(self):
        # 4 positions each with 25 USDC = 100 USDC total; use max_open_positions=10 so
        # the positions-count check doesn't fire before the exposure check
        positions = [make_position(condition_id=f"mkt-{i}", cost_basis=25.0) for i in range(4)]
        rm = self._make_rm(open_positions=positions, max_total_exposure_usdc=100.0, max_open_positions=10)
        decision = rm.evaluate(make_signal(condition_id="mkt-99"), 100.0, 0.0)
        assert not decision.approved
        assert "total exposure" in decision.reason

    def test_sell_signal_always_approved(self):
        rm = self._make_rm(max_daily_loss_usdc=0.0)
        signal = Signal("id", "Q?", "YES", SignalType.SELL, 0.35, 0.0, 0.0, "tp")
        decision = rm.evaluate(signal, current_balance=0.0, daily_loss_usdc=999.0)
        assert decision.approved

    def test_trade_size_capped_at_max(self):
        rm = self._make_rm(max_trade_size_usdc=5.0)
        decision = rm.evaluate(make_signal(), current_balance=1000.0, daily_loss_usdc=0.0)
        assert decision.approved
        assert decision.trade_size_usdc <= 5.0
