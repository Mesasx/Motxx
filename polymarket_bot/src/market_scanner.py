"""Scan and filter active Polymarket markets."""

from __future__ import annotations

from dataclasses import dataclass, field

from .config import Settings, get_settings
from .logger import get_logger
from .polymarket_client import MarketData, PolymarketClient

log = get_logger(__name__)


@dataclass
class ScanResult:
    total_fetched: int = 0
    total_parsed: int = 0
    passed_filters: int = 0
    markets: list[MarketData] = field(default_factory=list)


class MarketScanner:
    def __init__(
        self,
        client: PolymarketClient | None = None,
        settings: Settings | None = None,
    ) -> None:
        self._client = client or PolymarketClient()
        self._settings = settings or get_settings()

    def scan(self, enrich_clob: bool = False) -> ScanResult:
        s = self._settings
        result = ScanResult()

        log.info("Fetching active markets from Polymarket...")
        raw_markets = self._client.fetch_all_active_markets()
        result.total_fetched = len(raw_markets)
        log.info(f"Fetched {result.total_fetched} raw markets")

        parsed: list[MarketData] = []
        for raw in raw_markets:
            m = self._client.parse_market(raw)
            if m is not None:
                parsed.append(m)
        result.total_parsed = len(parsed)

        filtered: list[MarketData] = []
        for m in parsed:
            reason = self._filter(m)
            if reason:
                log.debug(f"SKIP [{m.condition_id[:12]}] {m.question[:60]}: {reason}")
            else:
                if enrich_clob:
                    self._client.enrich_with_clob_prices(m)
                filtered.append(m)

        result.passed_filters = len(filtered)
        result.markets = filtered
        log.info(
            f"Scan complete: {result.total_fetched} fetched → "
            f"{result.total_parsed} parsed → {result.passed_filters} passed filters"
        )
        return result

    def _filter(self, m: MarketData) -> str | None:
        """Return a rejection reason string, or None if the market passes."""
        s = self._settings

        if not m.active:
            return "not active"

        if m.volume < s.min_liquidity:
            return f"volume {m.volume:.0f} < {s.min_liquidity}"

        if m.hours_to_close < s.min_hours_to_close:
            return f"closes in {m.hours_to_close:.1f}h < {s.min_hours_to_close}h"

        if not m.clob_token_ids:
            return "no CLOB token IDs"

        if not m.token_prices:
            return "no token prices"

        # Check spread for YES token
        yes_tp = m.get_token_price("YES")
        if yes_tp is not None and yes_tp.spread > s.max_spread:
            return f"YES spread {yes_tp.spread:.4f} > {s.max_spread}"

        return None
