"""CLI entrypoint for the Polymarket Paper Trading Bot.

Usage:
    python -m src.main scan
    python -m src.main paper
    python -m src.main status
    python -m src.main dashboard
    python -m src.main export
    python -m src.main reset-paper
"""

from __future__ import annotations

import csv
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import typer
from rich.console import Console
from rich.table import Table

from .config import get_settings
from .logger import get_logger, setup_logger
from .market_scanner import MarketScanner
from .paper_executor import PaperExecutor
from .polymarket_client import PolymarketClient
from .portfolio import Portfolio
from .risk_manager import RiskManager
from .storage import Storage
from .strategy import Signal, SignalType, Strategy

app = typer.Typer(help="Polymarket Paper Trading Bot — simulation only, no real money.")
console = Console()


def _init() -> tuple[Storage, PaperExecutor, Portfolio, Strategy, RiskManager]:
    s = get_settings()
    setup_logger(s.log_level)
    storage = Storage(s.database_url)
    executor = PaperExecutor(storage=storage, settings=s)
    portfolio = Portfolio(storage=storage, settings=s)
    strategy = Strategy(settings=s)
    risk_manager = RiskManager(storage=storage, settings=s)

    # Restore balance from latest snapshot if it exists
    latest = storage.get_latest_snapshot()
    if latest is not None:
        executor.balance = latest.balance
    else:
        executor.balance = s.initial_paper_balance_usdc

    return storage, executor, portfolio, strategy, risk_manager


@app.command()
def scan():
    """Scan active Polymarket markets and display a summary table."""
    s = get_settings()
    setup_logger(s.log_level)

    console.rule("[bold blue]Polymarket Market Scanner[/bold blue]")
    console.print("[yellow]Fetching active markets…[/yellow]")

    with PolymarketClient(s) as client:
        scanner = MarketScanner(client=client, settings=s)
        result = scanner.scan(enrich_clob=False)

    table = Table(title=f"Active Markets ({result.passed_filters} passed)")
    table.add_column("Question", max_width=50, overflow="fold")
    table.add_column("Category", width=15)
    table.add_column("Volume", justify="right", width=12)
    table.add_column("Liquidity", justify="right", width=12)
    table.add_column("YES Price", justify="right", width=10)
    table.add_column("Spread", justify="right", width=8)
    table.add_column("Closes In", justify="right", width=10)

    for m in result.markets[:50]:
        yes_tp = m.get_token_price("YES")
        table.add_row(
            m.question[:50],
            m.category or "-",
            f"${m.volume:,.0f}",
            f"${m.liquidity:,.0f}",
            f"{yes_tp.midpoint:.3f}" if yes_tp else "-",
            f"{yes_tp.spread:.4f}" if yes_tp else "-",
            f"{m.hours_to_close:.0f}h",
        )

    console.print(table)
    console.print(
        f"\n[dim]Fetched: {result.total_fetched} | "
        f"Parsed: {result.total_parsed} | "
        f"Passed filters: {result.passed_filters}[/dim]"
    )


@app.command()
def paper(
    loops: int = typer.Option(0, help="Number of loops (0 = infinite)"),
    interval: int = typer.Option(0, help="Override poll interval in seconds (0 = use config)"),
):
    """Run the paper trading loop. Scans markets, generates signals, simulates trades."""
    storage, executor, portfolio, strategy, risk_manager = _init()
    s = get_settings()
    poll_interval = interval if interval > 0 else s.poll_interval_seconds

    console.rule("[bold green]Paper Trading Bot — SIMULATION ONLY[/bold green]")
    console.print(f"[bold]Initial balance:[/bold] {executor.balance:.2f} USDC")
    console.print(f"[bold]Poll interval:[/bold] {poll_interval}s")
    console.print("[dim]Press Ctrl+C to stop.[/dim]\n")

    loop_count = 0
    with PolymarketClient(s) as client:
        scanner = MarketScanner(client=client, settings=s)

        try:
            while True:
                loop_count += 1
                console.print(f"[cyan]── Loop {loop_count} ──[/cyan] {datetime.now(timezone.utc).strftime('%H:%M:%S')}")

                # Scan markets
                result = scanner.scan(enrich_clob=False)

                # --- Check exit signals on open positions ---
                open_positions = storage.get_open_positions()
                for pos in open_positions:
                    market = next(
                        (m for m in result.markets if m.condition_id == pos.condition_id), None
                    )
                    if market is None:
                        continue

                    tp = market.get_token_price(pos.outcome)
                    if tp is None:
                        continue

                    # Update position price
                    executor.update_position_price(
                        pos.id, tp.midpoint, pos.cost_basis, pos.quantity
                    )

                    # Check exit signal
                    exit_signal = strategy.generate_exit_signals(
                        condition_id=pos.condition_id,
                        question=pos.question,
                        outcome=pos.outcome,
                        avg_entry_price=pos.avg_entry_price,
                        current_price=tp.best_bid,
                        hours_to_close=market.hours_to_close,
                    )
                    if exit_signal:
                        order = executor.execute_sell(exit_signal, pos.id, pos.quantity)
                        if order:
                            realized = order.usdc_value - pos.cost_basis
                            executor.close_position(pos.id, realized, exit_signal.reason, order.price)
                            storage.save_signal({
                                **exit_signal.to_dict(),
                                "approved": True,
                                "rejection_reason": None,
                            })
                            console.print(
                                f"  [{'green' if realized > 0 else 'red'}]EXIT[/] "
                                f"{pos.outcome} | {pos.question[:40]} | "
                                f"PnL={realized:+.2f} USDC"
                            )

                # --- Generate entry signals ---
                stats = portfolio.compute_stats(executor.balance)
                daily_loss = portfolio.daily_loss(stats.equity)

                signals_generated = 0
                signals_approved = 0

                for market in result.markets:
                    entry_signals = strategy.generate_entry_signals(market)
                    for signal in entry_signals:
                        signals_generated += 1
                        decision = risk_manager.evaluate(
                            signal, executor.balance, daily_loss
                        )
                        storage.save_signal({
                            **signal.to_dict(),
                            "approved": decision.approved,
                            "rejection_reason": None if decision.approved else decision.reason,
                        })

                        if decision.approved:
                            signals_approved += 1
                            order = executor.execute_buy(signal, decision)
                            if order:
                                console.print(
                                    f"  [green]BUY[/green] {signal.outcome} | "
                                    f"{signal.question[:40]} | "
                                    f"{order.quantity:.4f} @ {order.price:.4f} = "
                                    f"{order.usdc_value:.2f} USDC"
                                )

                portfolio.take_snapshot(executor.balance)
                stats = portfolio.compute_stats(executor.balance)
                console.print(
                    f"  balance={stats.balance:.2f} equity={stats.equity:.2f} "
                    f"pnl={stats.total_pnl:+.2f} positions={stats.open_positions} "
                    f"signals={signals_generated}(+{signals_approved})"
                )

                if loops > 0 and loop_count >= loops:
                    break

                time.sleep(poll_interval)

        except KeyboardInterrupt:
            console.print("\n[yellow]Stopped by user.[/yellow]")

    console.print("\n[bold]Final Portfolio:[/bold]")
    _print_status(storage, executor.balance, portfolio)


@app.command()
def status():
    """Show current paper trading portfolio status."""
    storage, executor, portfolio, _, _ = _init()
    _print_status(storage, executor.balance, portfolio)


def _print_status(storage: Storage, balance: float, portfolio: Portfolio) -> None:
    stats = portfolio.compute_stats(balance)

    table = Table(title="Portfolio Status")
    table.add_column("Metric", style="bold")
    table.add_column("Value", justify="right")

    rows = [
        ("Initial Balance", f"${stats.initial_balance:.2f}"),
        ("Current Balance", f"${stats.balance:.2f}"),
        ("Equity", f"${stats.equity:.2f}"),
        ("Total PnL", f"${stats.total_pnl:+.2f}"),
        ("Realized PnL", f"${stats.realized_pnl:+.2f}"),
        ("Unrealized PnL", f"${stats.unrealized_pnl:+.2f}"),
        ("Drawdown", f"${stats.drawdown:.2f} ({stats.drawdown_pct:.1f}%)"),
        ("Open Positions", str(stats.open_positions)),
        ("Total Trades", str(stats.total_trades)),
        ("Win Rate", f"{stats.win_rate:.1f}%"),
        ("Total Exposure", f"${stats.total_exposure:.2f}"),
    ]
    for label, value in rows:
        table.add_row(label, value)
    console.print(table)

    open_pos = storage.get_open_positions()
    if open_pos:
        pos_table = Table(title="Open Positions")
        pos_table.add_column("Market", max_width=40, overflow="fold")
        pos_table.add_column("OUT", width=4)
        pos_table.add_column("Qty", justify="right")
        pos_table.add_column("Entry", justify="right")
        pos_table.add_column("Current", justify="right")
        pos_table.add_column("Cost", justify="right")
        pos_table.add_column("Value", justify="right")
        pos_table.add_column("PnL", justify="right")
        for p in open_pos:
            pnl = p.unrealized_pnl or 0.0
            pos_table.add_row(
                p.question[:40],
                p.outcome,
                f"{p.quantity:.4f}",
                f"{p.avg_entry_price:.4f}",
                f"{p.current_price:.4f}",
                f"${p.cost_basis:.2f}",
                f"${p.current_value:.2f}",
                f"[{'green' if pnl >= 0 else 'red'}]${pnl:+.2f}[/]",
            )
        console.print(pos_table)


@app.command()
def dashboard():
    """Launch the Streamlit dashboard."""
    dash_path = Path(__file__).parent / "dashboard.py"
    console.print(f"[bold]Launching dashboard:[/bold] streamlit run {dash_path}")
    subprocess.run([sys.executable, "-m", "streamlit", "run", str(dash_path)], check=False)


@app.command()
def export(output_dir: str = typer.Option("data/exports", help="Export directory")):
    """Export all data to CSV files."""
    storage, executor, portfolio, _, _ = _init()
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    def _write(name: str, rows: list, fields: list[str]) -> None:
        path = out / f"{name}.csv"
        with open(path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
        console.print(f"  [green]✓[/green] {path} ({len(rows)} rows)")

    console.print("[bold]Exporting data…[/bold]")

    signals = storage.get_signals(limit=10000)
    _write("signals", [
        {
            "id": s.id, "condition_id": s.condition_id, "question": s.question,
            "outcome": s.outcome, "signal_type": s.signal_type, "price": s.price,
            "spread": s.spread, "liquidity": s.liquidity, "reason": s.reason,
            "approved": s.approved, "rejection_reason": s.rejection_reason,
            "created_at": s.created_at,
        }
        for s in signals
    ], ["id", "condition_id", "question", "outcome", "signal_type", "price", "spread",
        "liquidity", "reason", "approved", "rejection_reason", "created_at"])

    orders = storage.get_orders(limit=10000)
    _write("orders", [
        {
            "id": o.id, "condition_id": o.condition_id, "question": o.question,
            "outcome": o.outcome, "side": o.side, "price": o.price,
            "quantity": o.quantity, "usdc_value": o.usdc_value,
            "slippage_usdc": o.slippage_usdc, "status": o.status, "created_at": o.created_at,
        }
        for o in orders
    ], ["id", "condition_id", "question", "outcome", "side", "price", "quantity",
        "usdc_value", "slippage_usdc", "status", "created_at"])

    positions = storage.get_all_positions()
    _write("positions", [
        {
            "id": p.id, "condition_id": p.condition_id, "question": p.question,
            "outcome": p.outcome, "avg_entry_price": p.avg_entry_price,
            "current_price": p.current_price, "quantity": p.quantity,
            "cost_basis": p.cost_basis, "current_value": p.current_value,
            "unrealized_pnl": p.unrealized_pnl, "realized_pnl": p.realized_pnl,
            "status": p.status, "close_reason": p.close_reason,
            "opened_at": p.opened_at, "closed_at": p.closed_at,
        }
        for p in positions
    ], ["id", "condition_id", "question", "outcome", "avg_entry_price", "current_price",
        "quantity", "cost_basis", "current_value", "unrealized_pnl", "realized_pnl",
        "status", "close_reason", "opened_at", "closed_at"])

    snapshots = storage.get_snapshots(limit=10000)
    _write("snapshots", [
        {
            "id": s.id, "timestamp": s.timestamp, "balance": s.balance,
            "equity": s.equity, "total_pnl": s.total_pnl, "realized_pnl": s.realized_pnl,
            "unrealized_pnl": s.unrealized_pnl, "open_positions": s.open_positions,
            "total_trades": s.total_trades, "winning_trades": s.winning_trades,
            "drawdown": s.drawdown, "peak_equity": s.peak_equity,
        }
        for s in snapshots
    ], ["id", "timestamp", "balance", "equity", "total_pnl", "realized_pnl",
        "unrealized_pnl", "open_positions", "total_trades", "winning_trades",
        "drawdown", "peak_equity"])

    console.print("[bold green]Export complete.[/bold green]")


@app.command(name="reset-paper")
def reset_paper(
    confirm: bool = typer.Option(False, "--confirm", help="Skip confirmation prompt"),
):
    """Reset all paper trading state (balance, positions, orders, signals, snapshots)."""
    if not confirm:
        typer.confirm(
            "This will delete all paper trading data. Continue?", abort=True
        )
    storage, executor, portfolio, _, _ = _init()
    storage.reset_paper_trading()
    console.print("[bold yellow]Paper trading state has been reset.[/bold yellow]")
    console.print(f"New balance: ${get_settings().initial_paper_balance_usdc:.2f} USDC")


if __name__ == "__main__":
    app()
