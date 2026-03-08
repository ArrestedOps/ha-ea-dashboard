# Home Assistant Add-on: EA Trading Dashboard

MetaTrader Expert Advisor Performance Tracking Dashboard

## About

This add-on provides a comprehensive trading dashboard for monitoring your MetaTrader 4/MT5 Expert Advisors directly in Home Assistant.

**Key Features:**
- Real-time account monitoring
- Performance analytics (Profit, Gain%, Win Rate)
- Live & Today's trades tracking
- Category filtering (Live/Copy/Demo accounts)
- Custom start dates for each account
- Webhook integration with MT4/MT5
- FastAPI backend with SQLite database
- Modern responsive web interface

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the "EA Trading Dashboard" add-on
3. Start the add-on
4. Open the web UI on port 8099

## Configuration

```yaml
log_level: info
database_path: /data/dashboard.db
retention_days: 730
```

### Options

- `log_level`: Set logging level (debug, info, warning, error)
- `database_path`: Path to SQLite database file
- `retention_days`: How long to keep closed trades (default: 730 days)

## MT4/MT5 Expert Advisor Setup

1. Copy the EA files from `/share/ea-dashboard/mt-experts/` to your MT4/MT5 Experts folder
2. Compile the EA in MetaEditor
3. Add your Home Assistant webhook URL to allowed URLs in MT4/MT5 settings
4. Attach the EA to a chart and configure:
   - **Webhook URL**: `http://YOUR_HA_IP:8099/api/webhook`
   - **EA Name**: Your account identifier
   - **Account Category**: Live, Copy, or Demo
   - **Start Date**: Your custom start date

## Support

- **Documentation**: See DOCS.md for detailed information
- **API Docs**: Available at `http://YOUR_HA_IP:8099/docs`
- **Issues**: Report bugs on GitHub

## Version

Current version: 5.0.0
