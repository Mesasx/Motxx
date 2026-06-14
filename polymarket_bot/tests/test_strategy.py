"""Tests for strategy.py"""

import pytest
from datetime import datetime, timezone, timedelta

from src.strategy import Strategy, SignalType
from src.polymarket_client import MarketData, TokenPrice
from src.config import Settings


def make_settings(**kwargs) -> Settings:
    defaults = dict(
        paper_trading=True,
        live_trading=False,
        entry_price_max=0.45,
        max_spread=0.03,
        min_liquidity=500.0,
        min_hours_to_close=24.0,
        exit_hours_before_close=6.0,
        take_profit_pct=0.15,
        stop_loss_pct=0.10,
        allow_no=False,
        initial_paper_balance_usdc=1000.0,
        max_trade_size_usdc=5.0,
        max_position_size_usdc=25.0,
        max_daily_loss_usdc=20.0,
        max_open_positions=5,
        max_market_exposure_usdc=25.0,
        max_total_exposure_usdc=100.0,
        slippage_bps=10,
        poll_interval_seconds=30,
        dashboard_refresh_seconds=10,
        database_url="sqlite:///:memory:",
        log_level="WARNING",
    )
    defaults.update(kwargs)
    return Settings(**defaults)


def make_market(
    condition_id: str = "test-id",
    question: str = "Will X happen?",
    yes_price: float = 0.30,
    spread: float = 0.02,
    volume: float = 1000.0,
    liquidity: float = 1000.0,
    hours_to_close: float = 48.0,
) -> MarketData:
    end_date = datetime.now(timezone.utc) + timedelta(hours=hours_to_close)
    yes_tp = TokenPrice(
        token_id="token-yes",
        outcome="YES",
        best_bid=yes_price - spread / 2,
        best_ask=yes_price + spread / 2,
        midpoint=yes_price,
        spread=spread,
    )
    return MarketData(
        condition_id=condition_id,
        question=question,
        category="politics",
        end_date=end_date,
        volume=volume,
        liquidity=liquidity,
        active=True,
        clob_token_ids=["token-yes", "token-no"],
        outcome_prices=[yes_price, 1.0 - yes_price],
        outcomes=["YES", "NO"],
        token_prices=[yes_tp],
    )


class TestEntrySignals:
    def test_generates_buy_when_conditions_met(self):
        strategy = Strategy(settings=make_settings())
        market = make_market(yes_price=0.30, spread=0.02)
        signals = strategy.generate_entry_signals(market)
        assert len(signals) == 1
        assert signals[0].signal_type == SignalType.BUY
        assert signals[0].outcome == "YES"

    def test_no_signal_when_price_above_max(self):
        strategy = Strategy(settings=make_settings(entry_price_max=0.40))
        market = make_market(yes_price=0.50)
        signals = strategy.generate_entry_signals(market)
        assert len(signals) == 0

    def test_no_signal_when_spread_too_wide(self):
        strategy = Strategy(settings=make_settings(max_spread=0.02))
        market = make_market(yes_price=0.30, spread=0.05)
        signals = strategy.generate_entry_signals(market)
        assert len(signals) == 0

    def test_no_signal_when_low_liquidity(self):
        strategy = Strategy(settings=make_settings(min_liquidity=1000.0))
        market = make_market(yes_price=0.30, liquidity=100.0)
        signals = strategy.generate_entry_signals(market)
        assert len(signals) == 0

    def test_no_signal_when_too_close_to_close(self):
        strategy = Strategy(settings=make_settings(min_hours_to_close=24.0))
        market = make_market(yes_price=0.30, hours_to_close=5.0)
        signals = strategy.generate_entry_signals(market)
        assert len(signals) == 0

    def test_allows_no_when_configured(self):
        no_price = TokenPrice(
            token_id="token-no",
            outcome="NO",
            best_bid=0.28,
            best_ask=0.32,
            midpoint=0.30,
            spread=0.02,
        )
        strategy = Strategy(settings=make_settings(allow_no=True, entry_price_max=0.45))
        market = make_market(yes_price=0.50)
        market.token_prices.append(no_price)
        # YES is above entry_price_max (0.50 > 0.45), but NO price (0.30) should trigger
        signals = strategy.generate_entry_signals(market)
        outcomes = [s.outcome for s in signals]
        assert "NO" in outcomes

    def test_no_signal_for_no_when_disabled(self):
        strategy = Strategy(settings=make_settings(allow_no=False))
        market = make_market(yes_price=0.50)
        no_tp = TokenPrice("t", "NO", 0.29, 0.31, 0.30, 0.02)
        market.token_prices.append(no_tp)
        signals = strategy.generate_entry_signals(market)
        assert not any(s.outcome == "NO" for s in signals)

    def test_signal_price_is_ask(self):
        """Entry price should be best_ask (we pay the ask when buying)."""
        strategy = Strategy(settings=make_settings())
        market = make_market(yes_price=0.30, spread=0.02)
        signals = strategy.generate_entry_signals(market)
        yes_tp = market.get_token_price("YES")
        assert signals[0].price == pytest.approx(yes_tp.best_ask)


class TestExitSignals:
    def test_take_profit_signal(self):
        strategy = Strategy(settings=make_settings(take_profit_pct=0.15))
        sig = strategy.generate_exit_signals(
            "id", "Q?", "YES",
            avg_entry_price=0.30,
            current_price=0.35,   # +16.7%
            hours_to_close=48.0,
        )
        assert sig is not None
        assert sig.signal_type == SignalType.SELL
        assert "take_profit" in sig.reason

    def test_stop_loss_signal(self):
        strategy = Strategy(settings=make_settings(stop_loss_pct=0.10))
        sig = strategy.generate_exit_signals(
            "id", "Q?", "YES",
            avg_entry_price=0.30,
            current_price=0.26,   # -13.3%
            hours_to_close=48.0,
        )
        assert sig is not None
        assert "stop_loss" in sig.reason

    def test_expiry_exit_signal(self):
        strategy = Strategy(settings=make_settings(exit_hours_before_close=6.0))
        sig = strategy.generate_exit_signals(
            "id", "Q?", "YES",
            avg_entry_price=0.30,
            current_price=0.32,
            hours_to_close=3.0,
        )
        assert sig is not None
        assert "expiry" in sig.reason

    def test_no_exit_when_conditions_not_met(self):
        strategy = Strategy(settings=make_settings())
        sig = strategy.generate_exit_signals(
            "id", "Q?", "YES",
            avg_entry_price=0.30,
            current_price=0.32,   # only +6.7%, below 15% TP
            hours_to_close=48.0,
        )
        assert sig is None

    def test_no_exit_with_zero_entry(self):
        strategy = Strategy(settings=make_settings())
        sig = strategy.generate_exit_signals("id", "Q?", "YES", 0.0, 0.35, 48.0)
        assert sig is None
