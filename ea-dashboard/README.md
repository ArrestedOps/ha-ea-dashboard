# EA Trading Dashboard

Home Assistant add-on for tracking MetaTrader Expert Advisors.

## Features

- Real-time trade tracking
- Multiple MT4/MT5 accounts
- Deposit management (manual + auto)
- Currency conversion (USD/EUR)
- Online status monitoring
- Detailed statistics & charts

## Configuration

```yaml
webhook_secret: ""  # Optional security token
log_level: "normal"  # or "debug" for troubleshooting
```

## Version 4.8.0

- Manual deposits (user-set, never overwritten)
- Auto deposits (MT4/MT5 detected)
- Configurable logging (normal/debug)
- Improved webhook error messages

See CHANGELOG.md for full history.
