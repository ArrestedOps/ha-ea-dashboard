# Changelog

## [2.0.1] - 2026-02-16

### Fixed
- Dashboard now loads real data from API instead of mock data
- Trades from MT4 EA now display correctly

### Technical
- Changed loadDataFromAPI() to fetch from /api/accounts
- Auto-fallback to mock data if API unavailable

## [2.0.0] - 2026-02-16

### Added
- Direct MT4/MT5 webhook integration
- Auto-create accounts from EA trades
- Category system (Live, Demo, Copy, Challenge)
- Manual EA management (edit/delete)
- Real-time trade updates
- Webhook security with secret keys
- MT4 Expert Advisor included
- MT5 Expert Advisor included

### Changed
- No external services needed
- Instant updates when trades close
- Simplified configuration

## [1.0.0] - 2026-02-16
- Initial demo version
