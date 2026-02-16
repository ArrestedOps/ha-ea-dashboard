# EA Trading Dashboard v3.2.0

Professional MetaTrader EA Statistics Dashboard for Home Assistant

## What's New in v3.2.0

- ✅ Live trades monitoring (real-time open positions)
- ✅ Initial balance / deposit tracking from MT4/MT5
- ✅ Proper gain % calculation
- ✅ Deleted accounts can be recreated
- ✅ Account detail pages
- ✅ Overall statistics dashboard
- ✅ Better table columns (most relevant first)
- ✅ MT4/MT5 EA sends live trades, deposits, withdrawals

## Installation

1. Add repository to Home Assistant:
   - Settings → Add-ons → Add-on Store → ⋮ → Repositories
   - Add: `https://github.com/ArrestedOps/ha-ea-dashboard`

2. Install "EA Trading Dashboard" add-on

3. Start the add-on

4. Install MT4/MT5 EA:
   - Copy `HA_TradeSync_MT4_v3.2.mq4` to `MQL4/Experts/`
   - Or `HA_TradeSync_MT5_v3.2.mq5` to `MQL5/Experts/`
   - Compile and attach to chart
   - Configure webhook URL in EA settings

## Features

- 📊 Multi-account dashboard
- 🔴 Live trades monitoring
- 📈 Real-time statistics
- 💰 Profit/Loss tracking
- 🎯 Win rate & profit factor
- 📉 Drawdown calculation
- 💱 Multi-currency support (USD/EUR)
- ⚙️ Account management

## Version

3.2.0
