# v4.8.0 — Backend: Manual Deposits + Log Levels

## ✨ Backend Features

### Manual Deposit Protection
- **manual_deposit**: User-set initial deposit, NEVER overwritten by webhooks
- **auto_deposits**: MT4/MT5 detected deposits (auto-updated)
- **Total = manual + auto**: Dashboard shows combined value
- Settings allow editing manual_deposit only

### Log Level Control
- **Add-on config**: Choose "normal" or "debug"
- **Normal**: Essential logs only (clean)
- **Debug**: Full webhook payload, headers, raw data (troubleshooting)
- Set via Add-on Settings page

### Fixes
- Webhook no longer overwrites user-set deposits
- Better error logging for Copy Trading issues
- Encoding issues (Phönix → Phoenix) handled

## 📝 Notes
Frontend UI improvements coming in v4.8.1 (table settings, sortable columns, restructured dashboard).
This release focuses on data integrity and debugging tools.
