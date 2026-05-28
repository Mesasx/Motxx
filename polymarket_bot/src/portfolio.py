"""Portfolio tracker: equity, PnL, drawdown, win rate."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone

from .config import Settings, get_settings
from .logger import get_logger
from .storage import Storage

log = get_logger(__name__)


@dataclass
class PortfolioStats:
    balance: float = 0.0
    equity: float = 0.0
    initial_balance: float = 0.0
    total_pnl: float = 0.0
    realized_pnl: float = 0.0
    unrealized_pnl: float = 0.0
    peak_equity: float = 0.0
    drawdown: float = 0.0          # absolute USDC drawdown
    drawdown_pct: float = 0.0      # percentage drawdown
    open_positions: int = 0
    total_trades: int = 0
    winning_trades: int = 0
    win_rate: float = 0.0
    total_exposure: float = 0.0


class Portfolio:
    def __init__(
        self,
        storage: Storage | None = None,
        settings: Settings | None = None,
        initial_balance: float | None = None,
    ) -> None:
        self._storage = storage or Storage()
        self._s = settings or get_settings()
        self._initial_balance = initial_balance or self._s.initial_paper_balance_usdc
        self._peak_equity: float = self._initial_balance

    def compute_stats(self, current_balance: float) -> PortfolioStats:
        positions = self._storage.get_open_positions()
        all_positions = self._storage.get_all_positions()

        unrealized_pnl = sum(p.unrealized_pnl or 0.0 for p in positions)
        realized_pnl = sum(
            p.realized_pnl or 0.0 for p in all_positions if p.status == "CLOSED"
        )
        total_exposure = sum(p.cost_basis or 0.0 for p in positions)

        equity = current_balance + total_exposure + unrealized_pnl
        total_pnl = equity - self._initial_balance

        if equity > self._peak_equity:
            self._peak_equity = equity

        drawdown = max(0.0, self._peak_equity - equity)
        drawdown_pct = (drawdown / self._peak_equity * 100.0) if self._peak_equity > 0 else 0.0

        closed = [p for p in all_positions if p.status == "CLOSED"]
        total_trades = len(closed)
        winning_trades = sum(1 for p in closed if (p.realized_pnl or 0.0) > 0)
        win_rate = (winning_trades / total_trades * 100.0) if total_trades > 0 else 0.0

        return PortfolioStats(
            balance=current_balance,
            equity=equity,
            initial_balance=self._initial_balance,
            total_pnl=total_pnl,
            realized_pnl=realized_pnl,
            unrealized_pnl=unrealized_pnl,
            peak_equity=self._peak_equity,
            drawdown=drawdown,
            drawdown_pct=drawdown_pct,
            open_positions=len(positions),
            total_trades=total_trades,
            winning_trades=winning_trades,
            win_rate=win_rate,
            total_exposure=total_exposure,
        )

    def daily_loss(self, current_equity: float) -> float:
        """Estimate daily loss from snapshots."""
        snaps = self._storage.get_snapshots(limit=1000)
        if not snaps:
            return 0.0
        today = datetime.now(timezone.utc).date()
        today_snaps = [
            s for s in snaps
            if (s.timestamp.replace(tzinfo=timezone.utc) if s.timestamp.tzinfo is None else s.timestamp).date() == today
        ]
        if not today_snaps:
            return 0.0
        first_equity_today = today_snaps[0].equity
        loss = first_equity_today - current_equity
        return max(0.0, loss)

    def take_snapshot(self, current_balance: float) -> None:
        stats = self.compute_stats(current_balance)
        self._storage.save_snapshot({
            "timestamp": datetime.now(timezone.utc),
            "balance": stats.balance,
            "equity": stats.equity,
            "total_pnl": stats.total_pnl,
            "realized_pnl": stats.realized_pnl,
            "unrealized_pnl": stats.unrealized_pnl,
            "open_positions": stats.open_positions,
            "total_trades": stats.total_trades,
            "winning_trades": stats.winning_trades,
            "drawdown": stats.drawdown,
            "peak_equity": stats.peak_equity,
        })
        log.debug(
            f"Snapshot: equity={stats.equity:.2f} pnl={stats.total_pnl:+.2f} "
            f"dd={stats.drawdown_pct:.1f}% positions={stats.open_positions}"
        )
