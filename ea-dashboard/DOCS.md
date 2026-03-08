# EA Trading Dashboard - Documentation

## Introduction

The EA Trading Dashboard is a Home Assistant add-on for monitoring MetaTrader 4/MT5 Expert Advisor performance in real-time.

## Features

### Dashboard
- **KPI Cards**: Total Balance, Profit, Accounts, Trades
- **Category Filters**: Filter by Live, Copy, or Demo accounts
- **Account Cards**: Visual representation with online status
- **Auto-Refresh**: Updates every 10 seconds

### Data Tracking
- Account information (balance, equity, deposits)
- Closed trades history
- Open trades monitoring
- Performance metrics (Win Rate, Profit Factor, Gain%)
- Custom start dates per account

### API
- RESTful API powered by FastAPI
- Automatic API documentation at `/docs`
- Webhook endpoint for MT4/MT5 integration

## Installation Steps

1. Navigate to Supervisor → Add-on Store
2. Add custom repository (if not already added)
3. Find "EA Trading Dashboard" in the list
4. Click "Install"
5. Click "Start"
6. Access dashboard at port 8099

## Configuration

### Add-on Configuration

```yaml
log_level: info           # Logging verbosity
database_path: /data/dashboard.db  # SQLite database path
retention_days: 730       # Days to keep closed trades
```

### MT4/MT5 Expert Advisor Configuration

#### Parameters:
- **WebhookURL**: `http://homeassistant.local:8099/api/webhook`
  - Replace with your actual Home Assistant IP
  - Example: `http://192.168.1.100:8099/api/webhook`

- **EAName**: Identifier for your account
  - Example: "Perceptrader AI Live"
  - This appears as the account name in the dashboard

- **AccountCategory**: Dropdown selection
  - `CATEGORY_LIVE` → Live trading account
  - `CATEGORY_COPY` → Copy trading account  
  - `CATEGORY_DEMO` → Demo account

- **StartDate**: Custom start date
  - Format: `D'YYYY.MM.DD HH:MM'`
  - Example: `D'2025.01.01 00:00'`
  - All trades before this date are ignored

- **WebhookInterval**: Update frequency in seconds
  - Recommended: 30-60 seconds for live, 60-120 for demo

#### Important: WebRequest Setup
In MT4/MT5 go to:
- Tools → Options → Expert Advisors
- Enable "Allow WebRequest for listed URLs"
- Add: `http://YOUR_HA_IP:8099/api/webhook`

## API Endpoints

### Accounts
- `GET /api/accounts` - List all accounts
- `GET /api/accounts/{id}` - Get account details
- `PUT /api/accounts/{id}` - Update account settings
- `DELETE /api/accounts/{id}` - Delete account

### Trades
- `GET /api/accounts/{id}/trades` - Get trades for account
- `GET /api/live-trades` - All open trades
- `GET /api/today-trades` - Trades closed today

### Analytics
- `GET /api/analytics/summary` - Portfolio summary

### Webhook
- `POST /api/webhook` - MT4/MT5 webhook endpoint

### Documentation
- `GET /docs` - Interactive API documentation (Swagger UI)
- `GET /health` - Health check

## Migration from v4.x

If you're upgrading from v4.x:

1. **Backup your data**: 
   ```bash
   cp /data/data.json /data/data.json.backup
   ```

2. **Stop the old version**

3. **Install v5.0**

4. **Run migration**:
   ```bash
   python3 /app/migrations/migrate_v4_to_v5.py
   ```

5. **Start v5.0**

The migration script will:
- Convert JSON data to SQLite
- Migrate all accounts and trades
- Preserve user settings
- Create backup of old data

## Troubleshooting

### Add-on won't start
- Check logs in Supervisor → EA Trading Dashboard → Logs
- Verify config.yaml is valid
- Ensure port 8099 is not in use

### MT4/MT5 webhook fails
- **Error 5200**: WebRequest URL not whitelisted
  - Solution: Add URL to MT4/MT5 allowed URLs
- **HTTP 404**: Dashboard not running or wrong URL
  - Solution: Check add-on is started, verify URL
- **HTTP 500**: Backend error
  - Solution: Check add-on logs

### No data in dashboard
- Verify EA is sending webhooks (check Expert log)
- Test webhook URL in browser: `http://YOUR_IP:8099/health`
- Check add-on logs for incoming requests

### Accounts disappearing
- In v5.0 this is fixed!
- Accounts are matched by account number only
- Manual settings (manual_deposit, online_timeout) are never overwritten

## Advanced

### Database Access
SQLite database location: `/data/dashboard.db`

Connect with:
```bash
sqlite3 /data/dashboard.db
```

Example queries:
```sql
-- View all accounts
SELECT * FROM accounts;

-- View recent trades
SELECT * FROM trades ORDER BY close_time DESC LIMIT 10;

-- Check webhook logs
SELECT * FROM webhook_logs WHERE status = 'error' LIMIT 10;
```

### Performance Tuning
- Adjust webhook interval based on number of EAs
- Use retention_days to limit database size
- Consider backup schedule for database

### Security
- Use HTTPS if exposing to internet
- Keep webhook URL private
- Regular database backups recommended

## Support

- **Documentation**: This file
- **API Docs**: http://YOUR_HA_IP:8099/docs
- **GitHub**: Report issues

## Version Information

- **Version**: 5.0.0
- **Backend**: FastAPI + SQLite
- **Frontend**: TailwindCSS + Alpine.js
- **Platform**: Python 3.11
