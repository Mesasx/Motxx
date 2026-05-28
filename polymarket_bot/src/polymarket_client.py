"""Read-only Polymarket API client.

Uses the public Gamma API (no auth) for market metadata and the public
CLOB API (no auth) for live prices.  No private keys, no order placement.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

import httpx

from .config import Settings, get_settings
from .logger import get_logger

log = get_logger(__name__)

GAMMA_BASE = "https://gamma-api.polymarket.com"
CLOB_BASE = "https://clob.polymarket.com"


@dataclass
class TokenPrice:
    token_id: str
    outcome: str       # "YES" or "NO"
    best_bid: float
    best_ask: float
    midpoint: float
    spread: float

    @property
    def price(self) -> float:
        return self.midpoint


@dataclass
class MarketData:
    condition_id: str
    question: str
    category: str
    end_date: datetime | None
    volume: float
    liquidity: float
    active: bool
    clob_token_ids: list[str] = field(default_factory=list)
    outcome_prices: list[float] = field(default_factory=list)
    outcomes: list[str] = field(default_factory=lambda: ["YES", "NO"])
    token_prices: list[TokenPrice] = field(default_factory=list)

    @property
    def hours_to_close(self) -> float:
        if self.end_date is None:
            return 999.0
        now = datetime.now(timezone.utc)
        end = self.end_date if self.end_date.tzinfo else self.end_date.replace(tzinfo=timezone.utc)
        delta = end - now
        return max(0.0, delta.total_seconds() / 3600.0)

    def get_token_price(self, outcome: str) -> TokenPrice | None:
        for tp in self.token_prices:
            if tp.outcome.upper() == outcome.upper():
                return tp
        return None


class PolymarketClient:
    """Public read-only client for Polymarket market data."""

    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()
        self._client = httpx.Client(
            timeout=30.0,
            headers={"User-Agent": "polymarket-paper-bot/1.0 (educational paper trading)"},
        )

    def close(self) -> None:
        self._client.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    # ── Gamma API ────────────────────────────────────────────────────────────

    def _gamma_get(self, path: str, params: dict | None = None) -> Any:
        url = f"{GAMMA_BASE}{path}"
        resp = self._client.get(url, params=params)
        resp.raise_for_status()
        return resp.json()

    def fetch_active_markets(self, limit: int = 100, offset: int = 0) -> list[dict]:
        """Fetch active, non-closed markets from Gamma API."""
        params = {
            "active": "true",
            "closed": "false",
            "archived": "false",
            "enableOrderBook": "true",
            "limit": limit,
            "offset": offset,
        }
        data = self._gamma_get("/markets", params=params)
        if isinstance(data, list):
            return data
        return data.get("data", data.get("markets", []))

    def fetch_all_active_markets(self, max_pages: int = 10) -> list[dict]:
        """Paginate through all active markets."""
        all_markets: list[dict] = []
        limit = 100
        for page in range(max_pages):
            batch = self.fetch_active_markets(limit=limit, offset=page * limit)
            if not batch:
                break
            all_markets.extend(batch)
            if len(batch) < limit:
                break
            log.debug(f"Fetched page {page+1}, total so far: {len(all_markets)}")
        return all_markets

    # ── CLOB API (public price endpoints) ────────────────────────────────────

    def _clob_get(self, path: str, params: dict | None = None) -> Any:
        url = f"{CLOB_BASE}{path}"
        resp = self._client.get(url, params=params)
        resp.raise_for_status()
        return resp.json()

    def fetch_price(self, token_id: str, side: str = "BUY") -> float | None:
        """Get best price for a token from CLOB."""
        try:
            data = self._clob_get("/price", params={"token_id": token_id, "side": side})
            return float(data.get("price", 0.0))
        except Exception as exc:
            log.warning(f"CLOB price fetch failed for {token_id}: {exc}")
            return None

    def fetch_midpoint(self, token_id: str) -> float | None:
        try:
            data = self._clob_get("/midpoint", params={"token_id": token_id})
            return float(data.get("mid", 0.0))
        except Exception as exc:
            log.warning(f"CLOB midpoint fetch failed for {token_id}: {exc}")
            return None

    def fetch_orderbook(self, token_id: str) -> dict | None:
        try:
            return self._clob_get("/book", params={"token_id": token_id})
        except Exception as exc:
            log.warning(f"CLOB orderbook fetch failed for {token_id}: {exc}")
            return None

    def build_token_price_from_clob(self, token_id: str, outcome: str) -> TokenPrice | None:
        """Build a TokenPrice by fetching bid/ask from CLOB."""
        bid = self.fetch_price(token_id, "SELL")
        ask = self.fetch_price(token_id, "BUY")
        if bid is None or ask is None:
            return None
        mid = (bid + ask) / 2.0
        spread = ask - bid
        return TokenPrice(
            token_id=token_id,
            outcome=outcome,
            best_bid=bid,
            best_ask=ask,
            midpoint=mid,
            spread=spread,
        )

    # ── Parsing ───────────────────────────────────────────────────────────────

    @staticmethod
    def _parse_json_field(value: Any) -> list:
        if value is None:
            return []
        if isinstance(value, list):
            return value
        if isinstance(value, str):
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return []
        return []

    @staticmethod
    def _parse_end_date(value: Any) -> datetime | None:
        if not value:
            return None
        if isinstance(value, datetime):
            return value
        try:
            from dateutil import parser as dp
            return dp.parse(str(value)).replace(tzinfo=timezone.utc)
        except Exception:
            return None

    def parse_market(self, raw: dict) -> MarketData | None:
        """Convert a raw Gamma API dict into a typed MarketData."""
        try:
            condition_id = raw.get("conditionId") or raw.get("condition_id") or raw.get("id", "")
            if not condition_id:
                return None

            clob_ids = self._parse_json_field(raw.get("clobTokenIds"))
            outcome_prices_raw = self._parse_json_field(raw.get("outcomePrices"))
            outcome_prices = [float(p) for p in outcome_prices_raw if p is not None]

            outcomes_raw = self._parse_json_field(raw.get("outcomes"))
            outcomes = [str(o) for o in outcomes_raw] if outcomes_raw else ["YES", "NO"]

            # volume: prefer volumeNum, fall back to volume24hr
            volume = float(
                raw.get("volumeNum")
                or raw.get("volume")
                or raw.get("volume24hr")
                or 0.0
            )
            liquidity = float(
                raw.get("liquidityNum")
                or raw.get("liquidity")
                or raw.get("liquidityClob")
                or 0.0
            )

            category = ""
            events = raw.get("events") or []
            if events and isinstance(events, list) and events[0]:
                ev = events[0]
                tags = ev.get("tags") or []
                if tags:
                    category = tags[0].get("label", "") if isinstance(tags[0], dict) else str(tags[0])

            market = MarketData(
                condition_id=str(condition_id),
                question=raw.get("question", ""),
                category=category,
                end_date=self._parse_end_date(raw.get("endDate") or raw.get("end_date")),
                volume=volume,
                liquidity=liquidity,
                active=bool(raw.get("active", True)),
                clob_token_ids=clob_ids,
                outcome_prices=outcome_prices,
                outcomes=outcomes,
            )

            # Build token prices from outcome_prices (Gamma) — lightweight
            for i, (token_id, outcome) in enumerate(zip(clob_ids, outcomes)):
                if i < len(outcome_prices):
                    price = outcome_prices[i]
                    complement = 1.0 - price
                    spread_est = abs(price - complement) * 0.02  # rough estimate
                    market.token_prices.append(
                        TokenPrice(
                            token_id=token_id,
                            outcome=outcome,
                            best_bid=max(0.0, price - spread_est / 2),
                            best_ask=min(1.0, price + spread_est / 2),
                            midpoint=price,
                            spread=spread_est,
                        )
                    )

            return market
        except Exception as exc:
            log.warning(f"Failed to parse market: {exc} | raw keys: {list(raw.keys())}")
            return None

    def enrich_with_clob_prices(self, market: MarketData) -> None:
        """Replace Gamma-estimated prices with live CLOB prices (best effort)."""
        enriched: list[TokenPrice] = []
        for tp in market.token_prices:
            live = self.build_token_price_from_clob(tp.token_id, tp.outcome)
            enriched.append(live if live else tp)
        market.token_prices = enriched
