# Changelog

All notable changes to EA Trading Dashboard will be documented in this file.

## [3.0.0] - 2026-02-16

### Added
- **Live Trades Monitor** - Real-time view of all open positions across accounts
- **Today's Trades** - Quick overview of trades closed today
- **Tabbed Interface** - Switch between Live and Today views
- **MyFxBook-Style Tables** - Professional sortable tables with all key metrics
- **Multi-Currency Support** - USD, EUR with automatic conversion
- **Exchange Rate Integration** - Daily updated USD/EUR rates
- **Account Management Modal** - Comprehensive settings per account
- **Manual Deposit Entry** - Set starting capital for accurate drawdown
- **Category Grouping** - Automatic sorting by Live/Copy/Demo
- **Sortable Columns** - Click any column header to sort
- **Enhanced Statistics** - Accurate profit, drawdown, profit factor
- **Days Running Counter** - Track account age automatically
- **Floating P/L Column** - See unrealized gains/losses
- **Withdrawals Tracking** - Record cash-outs
- **Quick Edit Buttons** - Direct access to account settings from table
- **Settings Button** - Floating action button for easy access
- **Display Currency Choice** - USD, EUR, or both simultaneously
- **Currency Display Options** - Show as "€2,750 (≈$2,978)"
- **Real-time Updates** - Auto-refresh every 10 seconds
- **Mobile Date Fix** - Removed microseconds for iOS/Safari compatibility
- **Ingress Proxy Fix** - Proper API URL handling

### Fixed
- **Profit Calculation** - Now sums ALL trades, not just visible ones
- **Drawdown Calculation** - Accurate with manual deposit option
- **Balance Chart** - Shows complete trade history, not just last 30
- **Mobile Date Parsing** - Fixed "Invalid Date" errors on mobile browsers
- **API URL Resolution** - Fixed Ingress proxy URL issues
- **Browser Cache** - Proper cache busting for updates
- **Sort Functionality** - Works correctly across all columns
- **Empty State Handling** - Better UI for accounts with no trades

### Changed
- **Complete UI Rebuild** - Professional MyFxBook-inspired design
- **Backend API Enhancement** - New endpoints for live/today trades
- **Data Structure** - Optimized account and trade storage
- **Performance** - Faster loading and rendering
- **Mobile Responsiveness** - Better tablet and phone support
- **Table Layout** - Horizontal scrolling on mobile for data integrity
- **Color Scheme** - More professional dark theme
- **Typography** - Better font hierarchy and readability

### Technical
- Added `/api/live-trades` endpoint
- Added `/api/today-trades` endpoint
- Added `/api/settings` endpoint with POST support
- Enhanced `/api/accounts` with full statistics
- Added currency conversion logic
- Added exchange rate caching
- Improved error handling
- Better logging for debugging
- Optimized database queries
- Added soft delete for accounts

## [2.0.2] - 2026-02-16

### Fixed
- API URLs to work with Home Assistant Ingress proxy
- Browser-based URL resolution for better compatibility

## [2.0.1] - 2026-02-16

### Fixed
- Dashboard now loads real data from API instead of mock data
- Proper API endpoint integration

## [2.0.0] - 2026-02-16

### Added
- Direct MT4/MT5 webhook integration
- Auto-create accounts from EA trades
- Category system (Live, Demo, Copy, Challenge)
- Manual EA management (edit/delete)
- Real-time trade updates
- Webhook security with secret keys
- MT4 Expert Advisor included (.mq4)
- MT5 Expert Advisor included (.mq5)

### Changed
- No external services needed (no MetaAPI)
- Instant updates when trades close
- Simplified configuration

### Removed
- MetaAPI dependency
- Cloud service requirements

## [1.0.0] - 2026-02-15

### Added
- Initial release with demo data
- Basic dashboard interface
- Multi-EA support
- Performance statistics
- Trade history view
- Balance charts
- Drawdown tracking
- Monthly returns

---

## Upgrade Notes

### From v2.x to v3.0
- **Data Migration:** Automatic, no action needed
- **New Config:** `webhook_secret` still optional
- **EA Update:** Not required, but recommended for best experience
- **Manual Steps:** 
  1. Update add-on via Home Assistant
  2. Optional: Set deposit manually in Settings for accurate drawdown
  3. Optional: Configure display currency preference

### From v1.x to v3.0
- **Breaking:** Demo data will be replaced with live data from EA
- **Required:** Install MT4/MT5 EA to start receiving trades
- **Config:** Add `webhook_secret` for security

---

## Future Releases

### Planned for v3.1
- Push notifications for large trades
- Email daily/weekly reports
- Risk management alerts
- CSV/Excel export
- Dark/Light mode toggle
- Performance comparison charts

### Planned for v4.0
- Multi-user support
- Advanced analytics dashboard
- AI-powered trade insights
- Mobile PWA app
- Backup/restore functionality
- Integration with more platforms

---

For full documentation, see [README.md](README.md)
