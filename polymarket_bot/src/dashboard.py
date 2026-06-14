"""Streamlit dashboard for the Polymarket Paper Trading Bot."""

from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

# Allow running as `streamlit run src/dashboard.py` from project root
sys.path.insert(0, str(Path(__file__).parent.parent))

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

from src.config import get_settings
from src.portfolio import Portfolio
from src.storage import Storage

# ── Page config ──────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Polymarket Paper Bot",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Load data ─────────────────────────────────────────────────────────────────
@st.cache_resource
def get_storage() -> Storage:
    s = get_settings()
    return Storage(s.database_url)


@st.cache_data(ttl=10)
def load_snapshots() -> pd.DataFrame:
    rows = get_storage().get_snapshots(limit=2000)
    if not rows:
        return pd.DataFrame()
    data = [
        {
            "timestamp": r.timestamp,
            "balance": r.balance,
            "equity": r.equity,
            "total_pnl": r.total_pnl,
            "realized_pnl": r.realized_pnl,
            "unrealized_pnl": r.unrealized_pnl,
            "open_positions": r.open_positions,
            "drawdown": r.drawdown,
            "total_trades": r.total_trades,
            "winning_trades": r.winning_trades,
        }
        for r in rows
    ]
    df = pd.DataFrame(data)
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
    return df


@st.cache_data(ttl=10)
def load_signals() -> pd.DataFrame:
    rows = get_storage().get_signals(limit=1000)
    if not rows:
        return pd.DataFrame()
    data = [
        {
            "id": r.id,
            "created_at": r.created_at,
            "condition_id": r.condition_id,
            "question": r.question,
            "outcome": r.outcome,
            "signal_type": r.signal_type,
            "price": r.price,
            "spread": r.spread,
            "liquidity": r.liquidity,
            "reason": r.reason,
            "approved": r.approved,
            "rejection_reason": r.rejection_reason,
        }
        for r in rows
    ]
    df = pd.DataFrame(data)
    df["created_at"] = pd.to_datetime(df["created_at"], utc=True)
    return df


@st.cache_data(ttl=10)
def load_orders() -> pd.DataFrame:
    rows = get_storage().get_orders(limit=1000)
    if not rows:
        return pd.DataFrame()
    data = [
        {
            "id": r.id,
            "created_at": r.created_at,
            "condition_id": r.condition_id,
            "question": r.question,
            "outcome": r.outcome,
            "side": r.side,
            "price": r.price,
            "quantity": r.quantity,
            "usdc_value": r.usdc_value,
            "slippage_usdc": r.slippage_usdc,
            "status": r.status,
        }
        for r in rows
    ]
    df = pd.DataFrame(data)
    df["created_at"] = pd.to_datetime(df["created_at"], utc=True)
    return df


@st.cache_data(ttl=10)
def load_positions() -> pd.DataFrame:
    rows = get_storage().get_all_positions()
    if not rows:
        return pd.DataFrame()
    data = [
        {
            "id": r.id,
            "condition_id": r.condition_id,
            "question": r.question,
            "outcome": r.outcome,
            "avg_entry_price": r.avg_entry_price,
            "current_price": r.current_price,
            "quantity": r.quantity,
            "cost_basis": r.cost_basis,
            "current_value": r.current_value,
            "unrealized_pnl": r.unrealized_pnl,
            "realized_pnl": r.realized_pnl,
            "status": r.status,
            "close_reason": r.close_reason,
            "opened_at": r.opened_at,
            "closed_at": r.closed_at,
        }
        for r in rows
    ]
    df = pd.DataFrame(data)
    df["opened_at"] = pd.to_datetime(df["opened_at"], utc=True)
    return df


def get_portfolio_stats():
    s = get_settings()
    storage = get_storage()
    portfolio = Portfolio(storage=storage, settings=s)
    snap = storage.get_latest_snapshot()
    balance = snap.balance if snap else s.initial_paper_balance_usdc
    return portfolio.compute_stats(balance), balance


# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.title("📊 Paper Bot")
    st.caption("Polymarket Simulation")
    st.divider()

    refresh = st.button("🔄 Refresh Data")
    if refresh:
        st.cache_data.clear()

    st.divider()
    st.subheader("Filters")
    filter_status = st.selectbox("Position Status", ["All", "OPEN", "CLOSED"])
    filter_outcome = st.selectbox("Outcome", ["All", "YES", "NO"])
    filter_signal_type = st.selectbox("Signal Type", ["All", "BUY", "SELL"])

    st.divider()
    s = get_settings()
    st.subheader("Config")
    st.caption(f"Initial balance: ${s.initial_paper_balance_usdc:.0f}")
    st.caption(f"Entry max price: {s.entry_price_max}")
    st.caption(f"Take profit: {s.take_profit_pct:.0%}")
    st.caption(f"Stop loss: {s.stop_loss_pct:.0%}")
    st.caption(f"Max spread: {s.max_spread}")
    st.caption(f"Max positions: {s.max_open_positions}")

# ── Main content ──────────────────────────────────────────────────────────────
st.title("📈 Polymarket Paper Trading Dashboard")
st.caption("Simulation only — no real money, no real orders")

stats, balance = get_portfolio_stats()

# ── 1. Summary metrics ────────────────────────────────────────────────────────
st.header("Portfolio Summary")
col1, col2, col3, col4, col5, col6 = st.columns(6)

pnl_color = "normal" if stats.total_pnl >= 0 else "inverse"
col1.metric("Balance", f"${stats.balance:.2f}")
col2.metric("Equity", f"${stats.equity:.2f}", f"{stats.total_pnl:+.2f}")
col3.metric("Total PnL", f"${stats.total_pnl:+.2f}")
col4.metric("Drawdown", f"${stats.drawdown:.2f}", f"-{stats.drawdown_pct:.1f}%", delta_color="inverse")
col5.metric("Win Rate", f"{stats.win_rate:.1f}%")
col6.metric("Open Positions", stats.open_positions)

col7, col8, col9 = st.columns(3)
col7.metric("Realized PnL", f"${stats.realized_pnl:+.2f}")
col8.metric("Unrealized PnL", f"${stats.unrealized_pnl:+.2f}")
col9.metric("Total Trades", stats.total_trades)

st.divider()

# ── 2. Charts ─────────────────────────────────────────────────────────────────
st.header("Performance Charts")
snaps_df = load_snapshots()

if snaps_df.empty:
    st.info("No snapshot data yet. Run `python -m src.main paper` to start trading.")
else:
    chart_col1, chart_col2 = st.columns(2)

    with chart_col1:
        fig_equity = px.line(
            snaps_df, x="timestamp", y="equity",
            title="Equity Curve",
            labels={"equity": "Equity (USDC)", "timestamp": "Time"},
        )
        fig_equity.add_hline(
            y=get_settings().initial_paper_balance_usdc,
            line_dash="dash", line_color="gray",
            annotation_text="Initial Balance"
        )
        st.plotly_chart(fig_equity, use_container_width=True)

    with chart_col2:
        fig_pnl = px.line(
            snaps_df, x="timestamp", y="total_pnl",
            title="Cumulative PnL",
            labels={"total_pnl": "PnL (USDC)", "timestamp": "Time"},
            color_discrete_sequence=["#00cc96"],
        )
        fig_pnl.add_hline(y=0, line_dash="dash", line_color="gray")
        st.plotly_chart(fig_pnl, use_container_width=True)

    chart_col3, chart_col4 = st.columns(2)

    with chart_col3:
        fig_dd = px.area(
            snaps_df, x="timestamp", y="drawdown",
            title="Drawdown (USDC)",
            labels={"drawdown": "Drawdown", "timestamp": "Time"},
            color_discrete_sequence=["#ef553b"],
        )
        st.plotly_chart(fig_dd, use_container_width=True)

    with chart_col4:
        # Daily PnL
        snaps_daily = snaps_df.copy()
        snaps_daily["date"] = snaps_daily["timestamp"].dt.date
        daily = snaps_daily.groupby("date")["total_pnl"].last().diff().fillna(0).reset_index()
        daily.columns = ["date", "daily_pnl"]
        daily["color"] = daily["daily_pnl"].apply(lambda x: "gain" if x >= 0 else "loss")
        fig_daily = px.bar(
            daily, x="date", y="daily_pnl",
            color="color",
            color_discrete_map={"gain": "#00cc96", "loss": "#ef553b"},
            title="Daily PnL",
            labels={"daily_pnl": "PnL (USDC)", "date": "Date"},
        )
        st.plotly_chart(fig_daily, use_container_width=True)

st.divider()

# ── 3. Positions ──────────────────────────────────────────────────────────────
st.header("Positions")
pos_df = load_positions()

if not pos_df.empty:
    if filter_status != "All":
        pos_df = pos_df[pos_df["status"] == filter_status]
    if filter_outcome != "All":
        pos_df = pos_df[pos_df["outcome"] == filter_outcome]

if pos_df.empty:
    st.info("No positions yet.")
else:
    # Exposure chart
    open_pos = pos_df[pos_df["status"] == "OPEN"]
    if not open_pos.empty:
        fig_exp = px.bar(
            open_pos, x="question", y="cost_basis",
            color="outcome",
            title="Exposure by Market (Open Positions)",
            labels={"cost_basis": "Cost Basis (USDC)", "question": "Market"},
        )
        fig_exp.update_xaxes(tickangle=45)
        st.plotly_chart(fig_exp, use_container_width=True)

    display_cols = [
        "question", "outcome", "status", "avg_entry_price", "current_price",
        "quantity", "cost_basis", "current_value", "unrealized_pnl", "realized_pnl",
        "close_reason", "opened_at",
    ]
    st.dataframe(
        pos_df[display_cols].rename(columns={
            "avg_entry_price": "entry_price",
            "current_price": "cur_price",
            "cost_basis": "cost",
            "current_value": "value",
            "unrealized_pnl": "unreal_pnl",
            "realized_pnl": "real_pnl",
        }),
        use_container_width=True,
        height=300,
    )

st.divider()

# ── 4. Signals ────────────────────────────────────────────────────────────────
st.header("Signals")
sig_df = load_signals()

if not sig_df.empty:
    if filter_outcome != "All":
        sig_df = sig_df[sig_df["outcome"] == filter_outcome]
    if filter_signal_type != "All":
        sig_df = sig_df[sig_df["signal_type"] == filter_signal_type]

if sig_df.empty:
    st.info("No signals yet.")
else:
    sig_col1, sig_col2 = st.columns(2)

    with sig_col1:
        approve_counts = sig_df["approved"].value_counts().reset_index()
        approve_counts.columns = ["approved", "count"]
        approve_counts["label"] = approve_counts["approved"].map({True: "Approved", False: "Rejected"})
        fig_approve = px.pie(
            approve_counts, values="count", names="label",
            title="Signals: Approved vs Rejected",
            color_discrete_map={"Approved": "#00cc96", "Rejected": "#ef553b"},
        )
        st.plotly_chart(fig_approve, use_container_width=True)

    with sig_col2:
        if "created_at" in sig_df.columns:
            sig_df["date"] = sig_df["created_at"].dt.date
            daily_sigs = sig_df.groupby(["date", "signal_type"]).size().reset_index(name="count")
            fig_sigs = px.bar(
                daily_sigs, x="date", y="count", color="signal_type",
                title="Signals Per Day",
                labels={"count": "# Signals", "date": "Date"},
            )
            st.plotly_chart(fig_sigs, use_container_width=True)

    display_sig = ["created_at", "question", "outcome", "signal_type", "price", "spread",
                   "liquidity", "approved", "reason", "rejection_reason"]
    st.dataframe(
        sig_df[display_sig],
        use_container_width=True,
        height=300,
    )

st.divider()

# ── 5. Orders ─────────────────────────────────────────────────────────────────
st.header("Simulated Orders")
ord_df = load_orders()

if ord_df.empty:
    st.info("No orders yet.")
else:
    ord_col1, ord_col2 = st.columns(2)
    with ord_col1:
        buy_count = len(ord_df[ord_df["side"] == "BUY"])
        sell_count = len(ord_df[ord_df["side"] == "SELL"])
        st.metric("Total Orders", len(ord_df))
        st.metric("Buy / Sell", f"{buy_count} / {sell_count}")
        total_slippage = ord_df["slippage_usdc"].sum()
        st.metric("Total Slippage Cost", f"${total_slippage:.4f}")

    display_ord = ["created_at", "question", "outcome", "side", "price",
                   "quantity", "usdc_value", "slippage_usdc", "status"]
    st.dataframe(
        ord_df[display_ord],
        use_container_width=True,
        height=300,
    )

st.divider()
st.caption("🔒 Paper trading only · No real funds · No real orders · Educational purposes")
