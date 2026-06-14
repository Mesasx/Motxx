from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Safety guards — must never allow live trading
    paper_trading: bool = True
    live_trading: bool = False

    # Balance
    initial_paper_balance_usdc: float = 1000.0

    # Strategy
    allow_no: bool = False
    entry_price_max: float = 0.45
    take_profit_pct: float = 0.15
    stop_loss_pct: float = 0.10

    # Risk
    max_trade_size_usdc: float = 5.0
    max_position_size_usdc: float = 25.0
    max_daily_loss_usdc: float = 20.0
    max_open_positions: int = 5
    max_market_exposure_usdc: float = 25.0
    max_total_exposure_usdc: float = 100.0

    # Filters
    max_spread: float = 0.03
    min_liquidity: float = 500.0
    min_hours_to_close: float = 24.0
    exit_hours_before_close: float = 6.0

    # Execution
    slippage_bps: int = 10
    poll_interval_seconds: int = 30
    dashboard_refresh_seconds: int = 10

    # Storage
    database_url: str = "sqlite:///data/polymarket_paper_bot.db"

    # Logging
    log_level: str = "INFO"

    # API endpoints (not in .env — hardcoded for safety)
    gamma_api_base: str = "https://gamma-api.polymarket.com"
    clob_api_base: str = "https://clob.polymarket.com"

    @field_validator("live_trading")
    @classmethod
    def block_live_trading(cls, v: bool) -> bool:
        if v:
            raise ValueError(
                "LIVE_TRADING must always be false. This is a paper trading bot only."
            )
        return v

    @model_validator(mode="after")
    def enforce_paper_trading(self) -> "Settings":
        if not self.paper_trading:
            raise ValueError("PAPER_TRADING must be true. Real trading is not supported.")
        if self.live_trading:
            raise ValueError("LIVE_TRADING must be false.")
        return self

    @property
    def slippage_fraction(self) -> float:
        return self.slippage_bps / 10_000.0


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings
