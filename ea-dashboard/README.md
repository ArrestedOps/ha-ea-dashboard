# EA Trading Dashboard v3.6.0

## 🔥 v3.6.0 - PROPER DATA FILTERING!

### ✅ FIXES:
- **Deposits filtered properly** - No longer counted as trades!
- **Profit calculation correct** - Only real trades counted
- **Best/Worst Trade correct** - Deposits excluded
- **Secret Key restored** - In add-on config
- **Detail page redesigned** - Modern, shows ALL trades
- **All calculations accurate** - Clean data = accurate results

### How EA Filters:
```
1. Check OrderComment() for "deposit", "balance", "withdrawal"
2. Check if swap=0, commission=0, profit=round number
3. Separate deposits from trades
4. Send only real trades to dashboard
```

### Detail Page Now Shows:
- Full trade history (scrollable table)
- Equity curve
- Top symbols breakdown
- ALL statistics from MyFxBook
- Deposits/Withdrawals separate
- Perfect calculations!

### Installation:
1. GitHub: Upload `github-v3.6/`
2. HA: Install v3.6.0
3. Set webhook secret in add-on config
4. MT4: Install EA v3.6
5. Done!

## Clean Data → Accurate Dashboard!
