# v4.6.1 — Hotfix

## 🐛 Critical Fixes
- **Dashboard empty**: Fixed fetchRates() blocking load() when network unavailable
- **Duplicate Settings button**: Removed bottom button, kept header button only
- **Error handling**: Dashboard now loads even if FX rates fail
- **Filter position**: Moved period filter tabs below KPI cards, above Live/Copy/Demo tables

## 📝 Notes
- FX rates are now optional - dashboard works without them
- Period filter (All Time/Today/Week/Month/Year) is visual only - shows all accounts
- Detailed period filtering available on detail pages
