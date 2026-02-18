# v4.7.0 — Advanced Filters + Unified Settings + Better Logging

## ✨ New Features

### Advanced Period Filters (10 options)
- **Today** — 00:00 today onwards
- **Yesterday** — Full yesterday (00:00 - 23:59)
- **This Week** — Monday 00:00 - now
- **Last Month** — 1st of last month - last day
- **This Year** — Jan 1 - now
- **Last Year** — Jan 1 last year - Dec 31 last year
- **Last 7 Days** — Rolling 7 days
- **Last 30 Days** — Rolling 30 days
- **Last 365 Days** — Rolling 365 days
- **All Time** — Everything

### Unified Settings Modal
- **Tabbed interface**: Currency / Accounts
- **Save All button**: One click saves all changes
- **Grid layout**: Easy overview of all accounts
- **Per-account controls**: Currency, Deposits, Online Timeout, Delete

### Trade History Pagination
- **25 trades per page**
- **Newest first** ordering
- **Navigation**: Prev/Next buttons + page number input
- **Page info**: "Page 2 of 15 (368 trades)"

## 🐛 Fixes
- **Webhook logging**: Detailed error messages for debugging Copy Trading issues
- **iOS dates**: Fixed "Invalid Date" on Safari
- **Currency conversion**: Works across all features
- **Online status**: Green/red dot + configurable timeout

## 📝 Technical
- Built on stable v4.6.2 base
- Cleaner settings UX
- Better error handling
