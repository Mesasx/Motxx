# Polymarket Paper Trading Bot

A professional **paper trading** (simulation only) bot for [Polymarket](https://polymarket.com) prediction markets, with a full Streamlit dashboard and SQLite persistence.

> **No real money. No real orders. No private keys. Educational purposes only.**

---

## Research & Inspiration

### Sources investigated

| Source | What was used |
|---|---|
| [Polymarket Gamma API docs](https://docs.polymarket.com) | Market endpoints, field names (`clobTokenIds`, `outcomePrices`, `endDate`, `volume`, `liquidity`) |
| [Polymarket/agents (official)](https://github.com/Polymarket/agents) | `GammaMarketClient` pattern, pagination with `offset`, field parsing (`outcomePrices`, `clobTokenIds` as JSON strings) |
| [Polymarket/py-clob-client (official)](https://github.com/Polymarket/py-clob-client) | CLOB base URL (`https://clob.polymarket.com`), public endpoints: `/price`, `/midpoint`, `/book` |
| [ThinkEnigmatic/polymarket-bot-arena](https://github.com/ThinkEnigmatic/polymarket-bot-arena) | SQLite architecture for trades and bots, paper trading mode concept |
| [OctoBot-Prediction-Market](https://github.com/Drakkar-Software/OctoBot-Prediction-Market) | Paper trading simulation concept, position management ideas |
| [warproxxx/poly-maker](https://github.com/warproxxx/poly-maker) | Market making spread calculation concepts |
| Streamlit trading dashboard patterns | Multi-page layout, plotly charts, sidebar filters |
| SQLAlchemy 2.x docs | ORM patterns, upsert logic, session management |

### Architecture decisions

- **Gamma API for discovery**: no auth needed, fast market listing with all metadata
- **CLOB API for live prices**: public endpoints `/price` and `/midpoint` give real bid/ask
- **Pydantic Settings**: env validation with hard blocks on `LIVE_TRADING=true`
- **SQLAlchemy ORM**: clean separation between domain logic and persistence
- **Modular design**: each module has one responsibility — easy to swap strategy or add new risk rules

---

## Architecture

```
src/
├── config.py           # Pydantic Settings; blocks live trading at startup
├── logger.py           # loguru structured logging to file + stderr
├── polymarket_client.py # Gamma + CLOB read-only API client
├── market_scanner.py   # Fetch + filter active markets
├── strategy.py         # Signal generation (entry + exit)
├── risk_manager.py     # Approve/reject signals with position/exposure limits
├── paper_executor.py   # Simulate orders with slippage (no real execution)
├── portfolio.py        # Track equity, PnL, drawdown, win rate
├── storage.py          # SQLite persistence (SQLAlchemy 2.x)
├── dashboard.py        # Streamlit dashboard
└── main.py             # Typer CLI
```

### Data flow

```
Gamma API → MarketScanner → Strategy → RiskManager → PaperExecutor → Storage
                                                                        ↓
                                                                  Dashboard (Streamlit)
```

---

## Installation

```bash
git clone <repo>
cd polymarket_bot
pip install -r requirements.txt
cp .env.example .env
# Edit .env to adjust parameters
```

---

## Configuration

All configuration is via `.env`. Key parameters:

| Variable | Default | Description |
|---|---|---|
| `PAPER_TRADING` | `true` | **Must stay true** |
| `LIVE_TRADING` | `false` | **Must stay false** |
| `INITIAL_PAPER_BALANCE_USDC` | `1000` | Starting balance |
| `ENTRY_PRICE_MAX` | `0.45` | Only buy if price ≤ this (looking for "cheap" outcomes) |
| `MAX_SPREAD` | `0.03` | Skip markets with spread > this |
| `MIN_LIQUIDITY` | `500` | Skip markets with volume < this |
| `TAKE_PROFIT_PCT` | `0.15` | Sell when PnL ≥ +15% |
| `STOP_LOSS_PCT` | `0.10` | Sell when PnL ≤ -10% |
| `MAX_OPEN_POSITIONS` | `5` | Hard limit on concurrent positions |
| `SLIPPAGE_BPS` | `10` | Simulated slippage (10 = 0.1%) |

---

## Running

### Scan markets
```bash
python -m src.main scan
```
Fetches active markets from Polymarket, filters them, and displays a summary table.

### Run paper trading
```bash
python -m src.main paper
# With custom loop count and interval:
python -m src.main paper --loops 10 --interval 60
```
Runs the full trading loop: scan → signals → risk check → simulate orders → save state.

### View portfolio status
```bash
python -m src.main status
```

### Launch dashboard
```bash
python -m src.main dashboard
# Or directly:
streamlit run src/dashboard.py
```

### Export data to CSV
```bash
python -m src.main export
# Output: data/exports/{signals,orders,positions,snapshots}.csv
```

### Reset paper trading state
```bash
python -m src.main reset-paper --confirm
```

---

## Dashboard

The Streamlit dashboard shows:

1. **Summary metrics**: balance, equity, total PnL, drawdown, win rate, open positions
2. **Performance charts**: equity curve, cumulative PnL, drawdown area, daily PnL bars
3. **Positions table**: open and closed with PnL, entry/current price
4. **Exposure chart**: cost basis per market for open positions
5. **Signals table**: all signals with approved/rejected status and reasons
6. **Orders table**: all simulated orders with slippage costs
7. **Sidebar filters**: filter by status, outcome, signal type

---

## Strategy

Current strategy: **threshold entry + take-profit/stop-loss exit**

**Entry signal (BUY YES)**:
- `price ≤ ENTRY_PRICE_MAX` (looking for "cheap" probabilities, e.g., <45%)
- `spread ≤ MAX_SPREAD` (market is liquid enough)
- `liquidity ≥ MIN_LIQUIDITY`
- `hours_to_close ≥ MIN_HOURS_TO_CLOSE`

**Exit signals (SELL)**:
- Take profit: `current_price / entry_price - 1 ≥ TAKE_PROFIT_PCT`
- Stop loss: `current_price / entry_price - 1 ≤ -STOP_LOSS_PCT`
- Expiry: `hours_to_close < EXIT_HOURS_BEFORE_CLOSE`

### Adding a new strategy

1. Create a new class in `src/strategy.py` (or a new file)
2. Implement `generate_entry_signals(market: MarketData) -> list[Signal]`
3. Implement `generate_exit_signals(...) -> Signal | None`
4. Wire it into `src/main.py`'s `paper()` command

---

## Risk management

The `RiskManager` checks each BUY signal against:

- Daily loss limit (`MAX_DAILY_LOSS_USDC`)
- Minimum balance for trade
- Max open positions (`MAX_OPEN_POSITIONS`)
- No duplicate position (same market + outcome)
- Per-market exposure cap (`MAX_MARKET_EXPOSURE_USDC`)
- Total portfolio exposure cap (`MAX_TOTAL_EXPOSURE_USDC`)

SELL signals always pass risk checks (exits are always allowed).

---

## Paper trading simulation

Orders are simulated with realistic costs:

- **BUY**: fills at `best_ask × (1 + slippage_fraction)`
- **SELL**: fills at `best_bid × (1 - slippage_fraction)`
- Slippage controlled by `SLIPPAGE_BPS` (basis points)
- Balance is deducted/credited after each simulated fill

---

## Tests

```bash
pytest tests/ -v
```

55 tests covering: strategy signals, risk rules, order simulation, PnL/drawdown calculation, and all storage CRUD operations.

---

## Limits & Risks

- This is **simulation only** — results do not guarantee real trading profitability
- Polymarket prices are from public APIs and may have latency
- Paper trading ignores gas fees, slippage on large orders, and market impact
- Prediction market probabilities are driven by news events — backtesting is limited
- The simple threshold strategy is educational; it is not a validated alpha signal

---

## Security

- `LIVE_TRADING=false` is enforced at the Pydantic model level — setting it to `true` raises a `ValueError` at startup
- No private keys, no wallet addresses, no on-chain transactions anywhere in the code
- All data stays local in SQLite
