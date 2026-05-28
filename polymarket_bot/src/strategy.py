"""Trading strategy: generates entry/exit signals.

Current strategy: threshold-based price entry for binary prediction markets.
  - BUY YES if price < ENTRY_PRICE_MAX and spread < MAX_SPREAD
  - BUY NO  if ALLOW_NO=true and NO price < ENTRY_PRICE_MAX
  - SELL (exit) if take-profit or stop-loss hit, or close to expiry
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum

from .config import Settings, get_settings
from .logger import get_logger
from .polymarket_client import MarketData, TokenPrice

log = get_logger(__name__)


class SignalType(str, Enum):
    BUY = "BUY"
    SELL = "SELL"
    HOLD = "HOLD"


@dataclass
class Signal:
    condition_id: str
    question: str
    outcome: str
    signal_type: SignalType
    price: float
    spread: float
    liquidity: float
    reason: str
    created_at: datetime = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)

    def to_dict(self) -> dict:
        return {
            "condition_id": self.condition_id,
            "question": self.question,
            "outcome": self.outcome,
            "signal_type": self.signal_type.value,
            "price": self.price,
            "spread": self.spread,
            "liquidity": self.liquidity,
            "reason": self.reason,
            "created_at": self.created_at,
        }


class Strategy:
    """Simple threshold-based entry/exit strategy."""

    def __init__(self, settings: Settings | None = None) -> None:
        self._s = settings or get_settings()

    def generate_entry_signals(self, market: MarketData) -> list[Signal]:
        signals: list[Signal] = []
        s = self._s

        outcomes_to_check = ["YES"]
        if s.allow_no:
            outcomes_to_check.append("NO")

        for outcome in outcomes_to_check:
            tp = market.get_token_price(outcome)
            if tp is None:
                continue

            signal = self._evaluate_entry(market, tp, outcome)
            if signal:
                signals.append(signal)

        return signals

    def _evaluate_entry(
        self, market: MarketData, tp: TokenPrice, outcome: str
    ) -> Signal | None:
        s = self._s

        # Price filter: only enter if price is "cheap" (undervalued)
        if tp.midpoint > s.entry_price_max:
            log.debug(
                f"HOLD {outcome} [{market.condition_id[:12]}]: "
                f"price {tp.midpoint:.3f} > {s.entry_price_max}"
            )
            return None

        # Spread filter
        if tp.spread > s.max_spread:
            log.debug(
                f"HOLD {outcome} [{market.condition_id[:12]}]: "
                f"spread {tp.spread:.4f} > {s.max_spread}"
            )
            return None

        # Liquidity filter
        if market.liquidity < s.min_liquidity:
            return None

        # Time to close filter
        if market.hours_to_close < s.min_hours_to_close:
            return None

        reason = (
            f"price {tp.midpoint:.3f} <= {s.entry_price_max}, "
            f"spread {tp.spread:.4f} <= {s.max_spread}, "
            f"liquidity {market.liquidity:.0f}"
        )
        return Signal(
            condition_id=market.condition_id,
            question=market.question,
            outcome=outcome,
            signal_type=SignalType.BUY,
            price=tp.best_ask,  # entry at ask
            spread=tp.spread,
            liquidity=market.liquidity,
            reason=reason,
        )

    def generate_exit_signals(
        self,
        condition_id: str,
        question: str,
        outcome: str,
        avg_entry_price: float,
        current_price: float,
        hours_to_close: float,
    ) -> Signal | None:
        s = self._s

        if avg_entry_price <= 0:
            return None

        pnl_pct = (current_price - avg_entry_price) / avg_entry_price

        # Take profit
        if pnl_pct >= s.take_profit_pct:
            return Signal(
                condition_id=condition_id,
                question=question,
                outcome=outcome,
                signal_type=SignalType.SELL,
                price=current_price,
                spread=0.0,
                liquidity=0.0,
                reason=f"take_profit: pnl={pnl_pct:.1%} >= {s.take_profit_pct:.1%}",
            )

        # Stop loss
        if pnl_pct <= -s.stop_loss_pct:
            return Signal(
                condition_id=condition_id,
                question=question,
                outcome=outcome,
                signal_type=SignalType.SELL,
                price=current_price,
                spread=0.0,
                liquidity=0.0,
                reason=f"stop_loss: pnl={pnl_pct:.1%} <= -{s.stop_loss_pct:.1%}",
            )

        # Time-based exit
        if hours_to_close < s.exit_hours_before_close:
            return Signal(
                condition_id=condition_id,
                question=question,
                outcome=outcome,
                signal_type=SignalType.SELL,
                price=current_price,
                spread=0.0,
                liquidity=0.0,
                reason=f"expiry_exit: {hours_to_close:.1f}h to close",
            )

        return None
