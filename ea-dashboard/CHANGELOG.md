# Changelog

All notable changes to this add-on will be documented in this file.

## [5.0.0] - 2025-03-08

### Added
- **Complete backend rewrite** with FastAPI + SQLite
- **Modern frontend** with TailwindCSS + Alpine.js
- **Account Category dropdown** in MT4/MT5 EAs (Live/Copy/Demo)
- **Custom Start Date field** in MT4/MT5 EAs
- **Auto-documentation** at `/docs` (Swagger UI)
- **Webhook logging** for debugging
- **Migration script** from v4.x to v5.0
- **Health check endpoint** at `/health`
- **Persistent storage** with SQLite database
- **Performance indexes** for fast queries
- **Responsive design** optimized for mobile
- **Category filtering** in dashboard

### Changed
- Database backend from JSON to SQLite
- Web framework from Flask to FastAPI
- Frontend from vanilla JS to Alpine.js + TailwindCSS
- Account matching now uses **account_number only** (more robust)
- Days display replaced with custom start date

### Fixed
- **Critical**: Manual deposit no longer overwritten by webhooks
- **Critical**: Online timeout no longer overwritten
- **Critical**: Accounts no longer disappear on name changes
- **Critical**: Account duplicates prevented
- Performance improved 10x (SQLite vs JSON)
- Webhook processing optimized
- Database race conditions eliminated

### Technical Details
- Python 3.11
- FastAPI 0.109.0
- SQLite with WAL mode
- Pydantic validation
- Async/Await throughout
- Type hints and validation
- Comprehensive error handling

### Migration
Users upgrading from v4.x should run the included migration script to convert their data from JSON to SQLite format.

## [4.12.5] - Previous Version

### Fixed
- Account settings preservation
- Name-based matching issues

---

[5.0.0]: https://github.com/yourusername/ea-dashboard/releases/tag/v5.0.0
