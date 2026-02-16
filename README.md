# EA Trading Dashboard v3.8.0

## 🔥 v3.8.0 - CONSERVATIVE + CORRECT DD!

### ✅ FIXES:
1. **EA Filtering**: ONLY OrderType 6/7 = Balance Operations
   - NO comment filtering (was too aggressive)
   - Golden Pickaxe trades now counted correctly!

2. **Drawdown CORRECT**: Tracks lowest point from peak
   ```
   OLD (WRONG): DD = (peak - current) / peak
   NEW (CORRECT): DD = (peak - lowest_from_peak) / peak
   ```
   Now matches MyFxBook!

### Golden Pickaxe Now Works:
```
Comment: "Transfer_from_206835_Wallet" 
→ NOT filtered as balance (comment ignored)
→ Only OrderType checked
→ Trades counted! ✅
```

### Drawdown Example:
```
Balance: 2000 → 2500 (peak) → 2300 → 2800 (new peak) → 2200
OLD: 21% DD (from 2800 to 2200)
NEW: 8% DD (max drop 2500→2300=200, 200/2500=8%) ✅
```

## Installation:
1. Upload v3.8
2. Install both EAs with v3.8
3. Check logs: "Real Trades: X"
4. Dashboard shows correct DD!
