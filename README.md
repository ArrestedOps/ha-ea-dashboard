# EA Dashboard v4.3.0 — Definitive Fix

## ROOT CAUSE FOUND:
Black Bull trade comments contain "Balanced" (#17164000 XAU Balanced[tp])
→ Previous EA filtered "balance" keyword → trades disappeared!

## v4.3 FIXES:
- EA uses SPECIFIC patterns only (Transfer_from_*_Wallet, DPST-*, VPS-*)
- NEVER uses generic "balance" keyword — appears in trade comments!
- Demo excluded from ALL overview metrics (balance, profit, trades)
- Demo excluded from Live/Today panels
- Detail page: cleaner, period filter, 3 charts

## EA Log should show:
```
BalanceOp: Transfer_from_206835_Wallet = $2000.00
Real Trades: 11
Balance Ops: 1
Deposits: $2000.00
```
