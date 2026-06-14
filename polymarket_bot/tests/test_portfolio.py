"""Tests for portfolio.py"""

import pytest
from unittest.mock import MagicMock
from datetime import datetime, timezone, timedelta

from src.portfolio import Portfolio
from src.storage import Storage, PositionRecord, SnapshotRecord
from src.config import Settings


def make_settings(**kwargs) -> Settings:
    defaults = dict(
        paper_trading=True, live_trading=False,
        initial_paper_balance_usdc=1000.0,
        max_trade_size_usdc=5.0, max_position_size_usdc=25.0,
        max_daily_loss_usdc=20.0, max_open_positions=5,
        max_market_exposure_usdc=25.0, max_total_exposure_usdc=100.0,
        max_spread=0.03, min_liquidity=500.0, min_hours_to_close=24.0,
        exit_hours_before_close=6.0, entry_price_max=0.45,
        take_profit_pct=0.15, stop_loss_pct=0.10, allow_no=False,
        slippage_bps=10, poll_interval_seconds=30, dashboard_refresh_seconds=10,
        database_url="sqlite:///:memory:", log_level="WARNING",
    )
    defaults.update(kwargs)
    return Settings(**defaults)


def make_position(status="OPEN", cost_basis=10.0, current_value=12.0, unrealized_pnl=2.0, realized_pnl=0.0, condition_id="mkt-1") -> PositionRecord:
    p = PositionRecord()
    p.condition_id = condition_id
    p.status = status
    p.cost_basis = cost_basis
    p.current_value = current_value
    p.unrealized_pnl = unrealized_pnl
    p.realized_pnl = realized_pnl
    return p


class TestPortfolioStats:
    def _make_portfolio(self, open_positions=None, all_positions=None, initial=1000.0):
        storage = MagicMock(spec=Storage)
        storage.get_open_positions.return_value = open_positions or []
        storage.get_all_positions.return_value = all_positions or []
        storage.save_snapshot.return_value = MagicMock()
        return Portfolio(storage=storage, settings=make_settings(initial_paper_balance_usdc=initial))

    def test_equity_includes_open_position_value(self):
        pos = make_position(status="OPEN", cost_basis=10.0, current_value=12.0, unrealized_pnl=2.0)
        portfolio = self._make_portfolio(open_positions=[pos], all_positions=[pos])
        stats = portfolio.compute_stats(current_balance=90.0)
        # equity = balance + cost_basis + unrealized = 90 + 10 + 2 = 102
        assert stats.equity == pytest.approx(102.0)

    def test_total_pnl_is_equity_minus_initial(self):
        portfolio = self._make_portfolio(initial=1000.0)
        stats = portfolio.compute_stats(current_balance=1050.0)
        assert stats.total_pnl == pytest.approx(50.0)

    def test_drawdown_computed_correctly(self):
        portfolio = self._make_portfolio(initial=1000.0)
        # Simulate a peak
        portfolio._peak_equity = 1100.0
        stats = portfolio.compute_stats(current_balance=1000.0)
        assert stats.drawdown == pytest.approx(100.0)
        assert stats.drawdown_pct == pytest.approx(100.0 / 1100.0 * 100.0)

    def test_win_rate_calculation(self):
        closed_win = make_position(status="CLOSED", realized_pnl=5.0)
        closed_loss = make_position(status="CLOSED", realized_pnl=-2.0)
        all_pos = [closed_win, closed_loss]
        portfolio = self._make_portfolio(all_positions=all_pos)
        stats = portfolio.compute_stats(1000.0)
        assert stats.total_trades == 2
        assert stats.winning_trades == 1
        assert stats.win_rate == pytest.approx(50.0)

    def test_zero_win_rate_with_no_trades(self):
        portfolio = self._make_portfolio()
        stats = portfolio.compute_stats(1000.0)
        assert stats.win_rate == 0.0

    def test_realized_pnl_from_closed_positions(self):
        closed = make_position(status="CLOSED", realized_pnl=15.0)
        portfolio = self._make_portfolio(all_positions=[closed])
        stats = portfolio.compute_stats(1000.0)
        assert stats.realized_pnl == pytest.approx(15.0)

    def test_unrealized_pnl_from_open_positions(self):
        pos = make_position(status="OPEN", unrealized_pnl=7.5)
        portfolio = self._make_portfolio(open_positions=[pos], all_positions=[pos])
        stats = portfolio.compute_stats(1000.0)
        assert stats.unrealized_pnl == pytest.approx(7.5)

    def test_peak_equity_updates(self):
        portfolio = self._make_portfolio(initial=1000.0)
        assert portfolio._peak_equity == pytest.approx(1000.0)
        portfolio.compute_stats(current_balance=1200.0)
        assert portfolio._peak_equity == pytest.approx(1200.0)

    def test_total_exposure(self):
        p1 = make_position(status="OPEN", cost_basis=10.0, condition_id="mkt-1")
        p2 = make_position(status="OPEN", cost_basis=15.0, condition_id="mkt-2")
        portfolio = self._make_portfolio(open_positions=[p1, p2], all_positions=[p1, p2])
        stats = portfolio.compute_stats(1000.0)
        assert stats.total_exposure == pytest.approx(25.0)
