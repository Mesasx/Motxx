"""Risk manager: approves or rejects signals before execution."""

from __future__ import annotations

from dataclasses import dataclass

from .config import Settings, get_settings
from .logger import get_logger
from .storage import Storage
from .strategy import Signal, SignalType

log = get_logger(__name__)


@dataclass
class RiskDecision:
    approved: bool
    reason: str
    trade_size_usdc: float = 0.0


class RiskManager:
    def __init__(
        self,
        storage: Storage | None = None,
        settings: Settings | None = None,
    ) -> None:
        self._storage = storage or Storage()
        self._s = settings or get_settings()

    def evaluate(
        self,
        signal: Signal,
        current_balance: float,
        daily_loss_usdc: float,
    ) -> RiskDecision:
        s = self._s

        if signal.signal_type == SignalType.SELL:
            return RiskDecision(approved=True, reason="exit signal — always approved", trade_size_usdc=0.0)

        # Daily loss limit
        if daily_loss_usdc >= s.max_daily_loss_usdc:
            return RiskDecision(
                approved=False,
                reason=f"daily_loss {daily_loss_usdc:.2f} >= limit {s.max_daily_loss_usdc:.2f}",
            )

        # Sufficient balance
        if current_balance < s.max_trade_size_usdc:
            return RiskDecision(
                approved=False,
                reason=f"balance {current_balance:.2f} < trade_size {s.max_trade_size_usdc:.2f}",
            )

        # Max open positions
        open_positions = self._storage.get_open_positions()
        if len(open_positions) >= s.max_open_positions:
            return RiskDecision(
                approved=False,
                reason=f"open positions {len(open_positions)} >= max {s.max_open_positions}",
            )

        # Duplicate position check
        existing = self._storage.get_open_position_by_market(
            signal.condition_id, signal.outcome
        )
        if existing is not None:
            return RiskDecision(
                approved=False,
                reason=f"already have open {signal.outcome} position on this market",
            )

        # Per-market exposure
        market_exposure = sum(
            p.cost_basis
            for p in open_positions
            if p.condition_id == signal.condition_id
        )
        if market_exposure >= s.max_market_exposure_usdc:
            return RiskDecision(
                approved=False,
                reason=f"market exposure {market_exposure:.2f} >= {s.max_market_exposure_usdc:.2f}",
            )

        # Total exposure
        total_exposure = sum(p.cost_basis for p in open_positions)
        if total_exposure >= s.max_total_exposure_usdc:
            return RiskDecision(
                approved=False,
                reason=f"total exposure {total_exposure:.2f} >= {s.max_total_exposure_usdc:.2f}",
            )

        # Calculate position size (min of max_trade_size and available balance)
        trade_size = min(s.max_trade_size_usdc, current_balance, s.max_position_size_usdc - market_exposure)
        if trade_size <= 0:
            return RiskDecision(approved=False, reason="computed trade_size <= 0")

        log.debug(f"APPROVED signal for {signal.outcome} on {signal.condition_id[:12]}, size={trade_size:.2f}")
        return RiskDecision(approved=True, reason="all checks passed", trade_size_usdc=trade_size)
