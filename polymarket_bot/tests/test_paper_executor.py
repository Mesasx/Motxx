"""Tests for paper_executor.py"""

import pytest
from unittest.mock import MagicMock

from src.paper_executor import PaperExecutor
from src.risk_manager import RiskDecision
from src.storage import Storage
from src.strategy import Signal, SignalType
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


def make_signal(price=0.30, outcome="YES") -> Signal:
    return Signal(
        condition_id="mkt-1",
        question="Will X?",
        outcome=outcome,
        signal_type=SignalType.BUY,
        price=price,
        spread=0.02,
        liquidity=1000.0,
        reason="test",
    )


def make_executor(balance=1000.0, slippage_bps=10):
    storage = MagicMock(spec=Storage)
    storage.save_order.return_value = MagicMock(id=1)
    storage.save_position.return_value = MagicMock(id=1)
    s = make_settings(slippage_bps=slippage_bps)
    executor = PaperExecutor(storage=storage, settings=s)
    executor.balance = balance
    return executor, storage


class TestBuyExecution:
    def test_buy_deducts_balance(self):
        executor, _ = make_executor(balance=100.0)
        signal = make_signal(price=0.30)
        decision = RiskDecision(approved=True, reason="ok", trade_size_usdc=5.0)
        order = executor.execute_buy(signal, decision)
        assert order is not None
        assert executor.balance < 100.0

    def test_buy_computes_slippage(self):
        """Buy price should be higher than signal price by slippage amount."""
        executor, _ = make_executor(slippage_bps=100)  # 1% slippage
        signal = make_signal(price=0.30)
        decision = RiskDecision(approved=True, reason="ok", trade_size_usdc=5.0)
        order = executor.execute_buy(signal, decision)
        assert order is not None
        assert order.price > signal.price
        assert order.price == pytest.approx(0.30 * 1.01)

    def test_buy_quantity_correct(self):
        executor, _ = make_executor(slippage_bps=0)  # zero slippage for easy math
        signal = make_signal(price=0.30)
        decision = RiskDecision(approved=True, reason="ok", trade_size_usdc=3.0)
        order = executor.execute_buy(signal, decision)
        assert order is not None
        assert order.quantity == pytest.approx(3.0 / 0.30)

    def test_buy_rejected_when_not_approved(self):
        executor, _ = make_executor()
        signal = make_signal()
        decision = RiskDecision(approved=False, reason="too risky", trade_size_usdc=0.0)
        order = executor.execute_buy(signal, decision)
        assert order is None

    def test_buy_rejected_when_insufficient_balance(self):
        executor, _ = make_executor(balance=1.0)
        signal = make_signal(price=0.30)
        decision = RiskDecision(approved=True, reason="ok", trade_size_usdc=5.0)
        order = executor.execute_buy(signal, decision)
        assert order is None

    def test_buy_stores_order_and_position(self):
        executor, storage = make_executor()
        signal = make_signal(price=0.30)
        decision = RiskDecision(approved=True, reason="ok", trade_size_usdc=5.0)
        executor.execute_buy(signal, decision)
        storage.save_order.assert_called_once()
        storage.save_position.assert_called_once()


class TestSellExecution:
    def test_sell_increases_balance(self):
        executor, _ = make_executor(balance=0.0)
        signal = Signal("mkt-1", "Q?", "YES", SignalType.SELL, 0.40, 0.0, 0.0, "tp")
        order = executor.execute_sell(signal, position_id=1, quantity=10.0)
        assert order is not None
        assert executor.balance > 0.0

    def test_sell_applies_slippage(self):
        """Sell price should be lower than signal price."""
        executor, _ = make_executor(slippage_bps=100)
        signal = Signal("mkt-1", "Q?", "YES", SignalType.SELL, 0.40, 0.0, 0.0, "tp")
        order = executor.execute_sell(signal, position_id=1, quantity=10.0)
        assert order.price < signal.price
        assert order.price == pytest.approx(0.40 * 0.99)

    def test_sell_proceeds_correct(self):
        executor, _ = make_executor(slippage_bps=0)
        signal = Signal("mkt-1", "Q?", "YES", SignalType.SELL, 0.40, 0.0, 0.0, "tp")
        order = executor.execute_sell(signal, position_id=1, quantity=10.0)
        assert order.usdc_value == pytest.approx(4.0)  # 10 * 0.40


class TestSlippageCalc:
    def test_zero_slippage(self):
        executor, _ = make_executor(slippage_bps=0)
        assert executor._apply_buy_slippage(0.30) == pytest.approx(0.30)
        assert executor._apply_sell_slippage(0.30) == pytest.approx(0.30)

    def test_slippage_caps_at_1(self):
        executor, _ = make_executor(slippage_bps=100_000)
        assert executor._apply_buy_slippage(0.99) <= 1.0

    def test_slippage_floors_at_0(self):
        executor, _ = make_executor(slippage_bps=100_000)
        assert executor._apply_sell_slippage(0.01) >= 0.0
