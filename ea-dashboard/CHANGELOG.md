# v4.6.0 — Bug Fixes + Major Features

## 🐛 Critical Fixes

### Deposit Detection
- **Demo accounts**: Now detects `initial_balance_on_demo_account` and `deposit_for_client`
- **Copy Trading (LiteFinance)**: Added support for `DPST-IT-INVEST-XXXXXX` format
- All existing patterns still work (Black Bull, LiteFinance standard)

### iOS Safari Compatibility
- **Date parsing**: MT4 sends `"2026.01.15 09:00"` which Safari rejects
  - Fixed: Auto-converts to ISO format `2026-01-15T09:00:00`
- **"Invalid Date" bug**: All trade history dates now parse correctly on iPhone/iPad

### Period Filter Accuracy
- **"Today" filter**: Now shows 00:00 today onwards (was: last 24 hours)
- **All other periods**: Week/Month/Year calculations unchanged

## 🎯 New Features

### 1. Online Status Monitoring
- **Green/Red dot** next to account name in overview table
- **Detail page**: Shows "● Online" or "● Offline (5m ago)"
- **Configurable timeout**: Set per-account in Settings (default: 60 seconds)
- Backend tracks `last_webhook` timestamp from MT4/MT5

### 2. Global Period Filter (Overview)
- **Filter tabs**: All Time / Today / This Week / This Month / This Year
- **Applies to**: Live, Copy, and Demo tables
- **Smart filtering**: Only shows accounts with trades in selected period

### 3. Trade History Pagination
- **25 trades per page** (newest first)
- **Navigation**: ← → buttons + page number input
- **Auto-reset**: Page 1 when changing periods

### 4. Sticky Back Button
- **Always visible** when scrolling on detail page
- **Fixed position**: Top-left corner

## 📝 Technical Notes

### EA Changes (v4.6)
- MT4: Added demo/copy deposit patterns
- MT5: Version bump only (already had correct patterns)
- Both: Updated to v4.60

### Backend
- `last_webhook` tracking in webhook endpoint
- `online_timeout` field per account
- `is_online` calculation in `/api/accounts`

### Frontend
- `parseDate()` function for iOS compatibility
- `filterPeriod()` uses 00:00 today for "today"
- `setOverviewPeriod()` global filter
- `changePage()` pagination handler

## 🔄 Migration Notes

Existing accounts will get:
- `online_timeout: 60` (default)
- `last_webhook: null` until first sync
- All other data preserved

No action required on upgrade.
