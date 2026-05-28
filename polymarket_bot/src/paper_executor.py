"""Paper trading executor.

Simulates order fills with configurable slippage.
Absolutely no real orders are ever placed.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from .config import Settings, get_settings
from .logger import get_logger
from .risk_manager import RiskDecision
from .storage import Storage
from .strategy import Signal, SignalType

log = get_logger(__name__)


@dataclass
class SimulatedOrder:
    condition_id: str
    question: str
    outcome: str
    side: str           # BUY / SELL
    price: float        # fill price after slippage
    quantity: float     # shares
    usdc_value: float   # cost in USDC
    slippage_usdc: float
    status: str = "FILLED"
    created_at: datetime = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)

    def to_dict(self) -> dict:
        return {
            "condition_id": self.condition_id,
            "question": self.question,
            "outcome": self.outcome,
            "side": self.side,
            "price": self.price,
            "quantity": self.quantity,
            "usdc_value": self.usdc_value,
            "slippage_usdc": self.slippage_usdc,
            "status": self.status,
            "created_at": self.created_at,
        }


class PaperExecutor:
    """Simulates paper trading — zero real money, zero real orders."""

    def __init__(
        self,
        storage: Storage | None = None,
        settings: Settings | None = None,
    ) -> None:
        self._storage = storage or Storage()
        self._s = settings or get_settings()
        # In-memory balance (persisted via snapshots)
        self._balance: float = self._s.initial_paper_balance_usdc

    @property
    def balance(self) -> float:
        return self._balance

    @balance.setter
    def balance(self, value: float) -> None:
        self._balance = max(0.0, value)

    def _apply_buy_slippage(self, price: float) -> float:
        """Buy at ask + slippage (we pay more)."""
        return min(1.0, price * (1.0 + self._s.slippage_fraction))

    def _apply_sell_slippage(self, price: float) -> float:
        """Sell at bid - slippage (we receive less)."""
        return max(0.0, price * (1.0 - self._s.slippage_fraction))

    def execute_buy(self, signal: Signal, decision: RiskDecision) -> SimulatedOrder | None:
        if not decision.approved or decision.trade_size_usdc <= 0:
            return None

        fill_price = self._apply_buy_slippage(signal.price)
        if fill_price <= 0:
            return None

        quantity = decision.trade_size_usdc / fill_price
        cost = quantity * fill_price
        slippage_cost = quantity * (fill_price - signal.price)

        if cost > self._balance:
            log.warning(f"Insufficient balance {self._balance:.2f} for order cost {cost:.2f}")
            return None

        self._balance -= cost

        order = SimulatedOrder(
            condition_id=signal.condition_id,
            question=signal.question,
            outcome=signal.outcome,
            side="BUY",
            price=fill_price,
            quantity=quantity,
            usdc_value=cost,
            slippage_usdc=abs(slippage_cost),
        )

        # Persist order
        self._storage.save_order(order.to_dict())

        # Open position
        self._storage.save_position({
            "condition_id": signal.condition_id,
            "question": signal.question,
            "outcome": signal.outcome,
            "avg_entry_price": fill_price,
            "current_price": fill_price,
            "quantity": quantity,
            "cost_basis": cost,
            "current_value": cost,
            "unrealized_pnl": 0.0,
            "realized_pnl": 0.0,
            "status": "OPEN",
        })

        log.info(
            f"[PAPER BUY] {signal.outcome} | {signal.question[:50]} | "
            f"qty={quantity:.4f} @ {fill_price:.4f} | cost={cost:.2f} USDC | "
            f"balance={self._balance:.2f}"
        )
        return order

    def execute_sell(self, signal: Signal, position_id: int, quantity: float) -> SimulatedOrder | None:
        fill_price = self._apply_sell_slippage(signal.price)
        if fill_price <= 0:
            return None

        proceeds = quantity * fill_price
        slippage_cost = quantity * (signal.price - fill_price)

        self._balance += proceeds

        order = SimulatedOrder(
            condition_id=signal.condition_id,
            question=signal.question,
            outcome=signal.outcome,
            side="SELL",
            price=fill_price,
            quantity=quantity,
            usdc_value=proceeds,
            slippage_usdc=abs(slippage_cost),
        )

        self._storage.save_order(order.to_dict())

        log.info(
            f"[PAPER SELL] {signal.outcome} | {signal.question[:50]} | "
            f"qty={quantity:.4f} @ {fill_price:.4f} | proceeds={proceeds:.2f} USDC | "
            f"balance={self._balance:.2f}"
        )
        return order

    def update_position_price(
        self, position_id: int, current_price: float, cost_basis: float, quantity: float
    ) -> None:
        current_value = quantity * current_price
        unrealized_pnl = current_value - cost_basis
        self._storage.update_position(position_id, {
            "current_price": current_price,
            "current_value": current_value,
            "unrealized_pnl": unrealized_pnl,
        })

    def close_position(
        self,
        position_id: int,
        realized_pnl: float,
        close_reason: str,
        fill_price: float,
    ) -> None:
        self._storage.update_position(position_id, {
            "status": "CLOSED",
            "realized_pnl": realized_pnl,
            "unrealized_pnl": 0.0,
            "current_price": fill_price,
            "close_reason": close_reason,
            "closed_at": datetime.now(timezone.utc),
        })
