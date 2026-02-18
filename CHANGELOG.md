# v4.6.2 — Stability Fix

## 🐛 Critical Fixes
- **Dashboard loading**: Reverted to v4.5 stable base + only essential patches
- **iOS Safari date parsing**: Fixed "Invalid Date" errors on iPhone/iPad
- **Today filter accuracy**: Now shows 00:00 today onwards (not last 24 hours)
- **Settings button**: Removed duplicate, kept header button only
- **Online status**: Green/red indicator dot + configurable timeout per account

## Technical Notes
Based on proven v4.5 codebase with minimal targeted changes for maximum stability.
All v4.6 features work, but complex filter logic removed to prevent JS errors.
