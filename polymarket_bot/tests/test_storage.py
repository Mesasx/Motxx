"""Tests for storage.py"""

import pytest
from datetime import datetime, timezone

from src.storage import Storage


@pytest.fixture
def storage():
    """In-memory SQLite storage for testing."""
    return Storage("sqlite:///:memory:")


class TestMarkets:
    def test_upsert_and_get_market(self, storage):
        data = {
            "condition_id": "cond-1",
            "question": "Will X happen?",
            "volume": 1000.0,
            "liquidity": 500.0,
            "active": True,
        }
        storage.upsert_market(data)
        markets = storage.get_markets(active_only=True)
        assert len(markets) == 1
        assert markets[0].condition_id == "cond-1"

    def test_upsert_updates_existing_market(self, storage):
        storage.upsert_market({"condition_id": "cond-1", "question": "Q?", "volume": 100.0, "active": True})
        storage.upsert_market({"condition_id": "cond-1", "question": "Q?", "volume": 999.0, "active": True})
        markets = storage.get_markets()
        assert len(markets) == 1
        assert markets[0].volume == pytest.approx(999.0)


class TestSignals:
    def test_save_and_get_signals(self, storage):
        data = {
            "condition_id": "cond-1",
            "question": "Q?",
            "outcome": "YES",
            "signal_type": "BUY",
            "price": 0.30,
            "approved": True,
        }
        storage.save_signal(data)
        signals = storage.get_signals()
        assert len(signals) == 1
        assert signals[0].outcome == "YES"
        assert signals[0].approved is True

    def test_multiple_signals(self, storage):
        for i in range(5):
            storage.save_signal({
                "condition_id": f"cond-{i}",
                "question": f"Q{i}?",
                "outcome": "YES",
                "signal_type": "BUY",
                "price": 0.30,
                "approved": i % 2 == 0,
            })
        signals = storage.get_signals()
        assert len(signals) == 5


class TestOrders:
    def test_save_and_get_orders(self, storage):
        data = {
            "condition_id": "cond-1",
            "question": "Q?",
            "outcome": "YES",
            "side": "BUY",
            "price": 0.31,
            "quantity": 16.0,
            "usdc_value": 5.0,
            "slippage_usdc": 0.005,
            "status": "FILLED",
        }
        storage.save_order(data)
        orders = storage.get_orders()
        assert len(orders) == 1
        assert orders[0].side == "BUY"
        assert orders[0].price == pytest.approx(0.31)


class TestPositions:
    def test_save_and_get_open_positions(self, storage):
        data = {
            "condition_id": "cond-1",
            "question": "Q?",
            "outcome": "YES",
            "avg_entry_price": 0.31,
            "current_price": 0.31,
            "quantity": 16.0,
            "cost_basis": 5.0,
            "current_value": 5.0,
            "unrealized_pnl": 0.0,
            "realized_pnl": 0.0,
            "status": "OPEN",
        }
        storage.save_position(data)
        positions = storage.get_open_positions()
        assert len(positions) == 1
        assert positions[0].outcome == "YES"

    def test_update_position(self, storage):
        data = {
            "condition_id": "cond-1", "question": "Q?", "outcome": "YES",
            "avg_entry_price": 0.30, "current_price": 0.30, "quantity": 10.0,
            "cost_basis": 3.0, "current_value": 3.0, "unrealized_pnl": 0.0,
            "realized_pnl": 0.0, "status": "OPEN",
        }
        storage.save_position(data)
        positions = storage.get_open_positions()
        pid = positions[0].id
        storage.update_position(pid, {"current_price": 0.40, "unrealized_pnl": 1.0})
        updated = storage.get_open_positions()
        assert updated[0].current_price == pytest.approx(0.40)
        assert updated[0].unrealized_pnl == pytest.approx(1.0)

    def test_get_open_position_by_market(self, storage):
        data = {
            "condition_id": "cond-abc", "question": "Q?", "outcome": "YES",
            "avg_entry_price": 0.30, "current_price": 0.30, "quantity": 10.0,
            "cost_basis": 3.0, "current_value": 3.0, "unrealized_pnl": 0.0,
            "realized_pnl": 0.0, "status": "OPEN",
        }
        storage.save_position(data)
        pos = storage.get_open_position_by_market("cond-abc", "YES")
        assert pos is not None
        assert pos.outcome == "YES"

    def test_no_open_position_for_wrong_market(self, storage):
        pos = storage.get_open_position_by_market("nonexistent", "YES")
        assert pos is None


class TestSnapshots:
    def test_save_and_get_snapshots(self, storage):
        data = {
            "timestamp": datetime.now(timezone.utc),
            "balance": 950.0,
            "equity": 960.0,
            "total_pnl": -40.0,
            "peak_equity": 1000.0,
        }
        storage.save_snapshot(data)
        snaps = storage.get_snapshots()
        assert len(snaps) == 1
        assert snaps[0].balance == pytest.approx(950.0)

    def test_get_latest_snapshot(self, storage):
        for i in range(3):
            storage.save_snapshot({
                "timestamp": datetime.now(timezone.utc),
                "balance": float(900 + i * 10),
                "equity": float(910 + i * 10),
                "total_pnl": float(-90 + i * 10),
                "peak_equity": 1000.0,
            })
        latest = storage.get_latest_snapshot()
        assert latest is not None
        assert latest.balance == pytest.approx(920.0)


class TestReset:
    def test_reset_clears_all_data(self, storage):
        storage.save_signal({"condition_id": "c1", "question": "Q?", "outcome": "YES",
                              "signal_type": "BUY", "price": 0.3, "approved": True})
        storage.save_order({"condition_id": "c1", "question": "Q?", "outcome": "YES",
                             "side": "BUY", "price": 0.3, "quantity": 10.0,
                             "usdc_value": 3.0, "slippage_usdc": 0.0, "status": "FILLED"})
        storage.save_position({"condition_id": "c1", "question": "Q?", "outcome": "YES",
                                "avg_entry_price": 0.3, "current_price": 0.3, "quantity": 10.0,
                                "cost_basis": 3.0, "current_value": 3.0, "unrealized_pnl": 0.0,
                                "realized_pnl": 0.0, "status": "OPEN"})
        storage.save_snapshot({"timestamp": datetime.now(timezone.utc), "balance": 997.0,
                                "equity": 1000.0, "total_pnl": 0.0, "peak_equity": 1000.0})
        storage.reset_paper_trading()
        assert storage.get_signals() == []
        assert storage.get_orders() == []
        assert storage.get_open_positions() == []
        assert storage.get_snapshots() == []
