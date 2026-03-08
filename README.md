# EA Trading Dashboard - Home Assistant Add-on Repository

Home Assistant Add-on for monitoring MetaTrader 4/MT5 Expert Advisors.

## Installation

### Method 1: Add Repository URL to Home Assistant

1. In Home Assistant: **Supervisor** → **Add-on Store** → **⋮** (three dots) → **Repositories**
2. Add this URL: `https://github.com/ArrestedOps/ha-ea-dashboard`
3. Click **Add** → **Close**
4. Refresh the Add-on Store page
5. Find **EA Trading Dashboard** in the list
6. Click **Install**

### Method 2: Upload to GitHub

1. Create a new GitHub repository: `ha-ea-dashboard`
2. Upload these files:
   ```
   repository.yaml
   ea-dashboard/
   ```
3. Go to repository settings → Enable GitHub Pages (optional)
4. Use your repository URL in Home Assistant

## Repository Structure

```
ha-ea-dashboard/
├── repository.yaml              # Repository metadata
└── ea-dashboard/                # The add-on
    ├── config.yaml              # Add-on configuration
    ├── Dockerfile               # Container build
    ├── build.yaml               # Build config
    ├── run.sh                   # Startup script
    ├── README.md                # Add-on description
    ├── DOCS.md                  # Full documentation
    ├── CHANGELOG.md             # Version history
    ├── requirements.txt         # Python dependencies
    ├── rootfs/                  # Application files
    │   └── app/
    │       ├── main.py          # FastAPI backend
    │       ├── database.py      # SQLite
    │       ├── models.py        # Pydantic models
    │       ├── webhook.py       # Webhook handler
    │       ├── schema.sql       # Database schema
    │       ├── crud/            # CRUD operations
    │       └── static/          # Frontend (Alpine.js + Tailwind)
    ├── migrations/              # v4→v5 migration
    └── mt-experts/              # MT4/MT5 Expert Advisors
        ├── HA_TradeSync_MT4_v5.0.mq4
        ├── HA_TradeSync_MT5_v5.0.mq5
        └── README.md
```

## Features

- **Real-time Monitoring**: Track MT4/MT5 Expert Advisors live
- **Performance Analytics**: Profit, Gain%, Win Rate, Profit Factor
- **Category Filtering**: Live, Copy, Demo accounts
- **Custom Start Dates**: Set individual start dates per account
- **Modern UI**: Dark theme, responsive design
- **FastAPI Backend**: RESTful API with auto-documentation
- **SQLite Database**: Persistent storage with migrations

## Version

Current: **v5.0.0**

## Support

- **Documentation**: See ea-dashboard/DOCS.md
- **API Docs**: Available at `http://YOUR_HA_IP:8099/docs`
- **Issues**: GitHub Issues

## License

MIT
