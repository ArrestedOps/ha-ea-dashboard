# 📊 EA Trading Dashboard — Home Assistant Add-on

A professional, real-time trading dashboard for **MetaTrader 4 & 5** accounts, running as a **Home Assistant Add-on**. Tracks multiple EA accounts across brokers, supports multi-currency display, and provides detailed performance analytics.

![Dashboard Preview](docs/preview.png)

---

## ✨ Features

- **Multi-Account Support** — Live, Copy, and Demo accounts in one view
- **Real-Time Updates** — Trades sync every 10 seconds via MT4/MT5 EA
- **Multi-Broker Compatible** — LiteFinance, Black Bull, IC Markets, and more
- **MT4 & MT5 EAs** — Expert Advisors for both platforms included
- **Currency Conversion** — Live USD ↔ EUR conversion (hourly rate refresh)
- **Period Filters** — Today / This Week / This Month / This Year / All Time
- **Detailed Analytics** — Equity curve, win/loss chart, monthly performance, drawdown
- **Mobile Responsive** — Fully optimized for iPhone and Android
- **Demo Excluded** — Overview totals only count Live and Copy accounts

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Network                         │
│                                                         │
│  ┌──────────────┐     WebRequest      ┌──────────────┐  │
│  │  MT4 / MT5   │ ──────────────────► │  Reverse     │  │
│  │  (EA sends   │  POST /api/webhook  │  Proxy       │  │
│  │   trades)    │        /batch       │  (Port 443)  │  │
│  └──────────────┘                     └──────┬───────┘  │
│                                              │           │
│                                     ┌────────▼────────┐  │
│  ┌──────────────┐                   │  Home Assistant │  │
│  │   Browser    │ ◄─────────────── │  Add-on         │  │
│  │  Dashboard   │    Port 7842      │  Port 7842      │  │
│  └──────────────┘                   └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Data Flow
1. MT4/MT5 EA sends trade data to your webhook URL every 10 seconds
2. The add-on backend (Python/Flask) stores and processes the data
3. The frontend polls `/api/*` endpoints and renders the dashboard
4. Live FX rates are fetched from `frankfurter.app` for currency conversion

---

## 📋 Requirements

- **Home Assistant OS** or **Home Assistant Supervised**
- A **publicly reachable webhook URL** (via reverse proxy or port forwarding)
- **MT4 or MT5** with Expert Advisor support
- The EA URL must be added to MT4's allowed WebRequest list

---

## 🚀 Installation

### Step 1 — Add the Repository

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click the **⋮ menu** (top right) → **Repositories**
3. Add this URL:
   ```
   https://github.com/YOUR_USERNAME/YOUR_REPO
   ```
4. Click **Add** → **Close**

### Step 2 — Install the Add-on

1. Find **EA Trading Dashboard** in the store
2. Click **Install**
3. Wait for the installation to complete

### Step 3 — Configure

Go to the **Configuration** tab:

```yaml
secret_key: "your-strong-secret-key-here"
history_days: 365
port: 7842
```

| Option | Description | Default |
|--------|-------------|---------|
| `secret_key` | Shared secret between EA and backend | `changeme` |
| `history_days` | Days of trade history to fetch from MT4/MT5 | `365` |
| `port` | Port the dashboard listens on | `7842` |

### Step 4 — Start the Add-on

Click **Start** and then open the **Web UI**.

---

## 🔌 Reverse Proxy Setup

The MT4 EA needs to reach your webhook from the internet. Set up a reverse proxy on your router or server.

### Option A: NGINX Proxy Manager (Recommended)

1. Open **NGINX Proxy Manager** in Home Assistant or a separate instance
2. Add a **Proxy Host**:

| Setting | Value |
|---------|-------|
| Domain Name | `your-domain.example.com` |
| Scheme | `http` |
| Forward Hostname / IP | `homeassistant.local` or your HA IP |
| Forward Port | `7842` |
| SSL | ✅ Enable with Let's Encrypt |

3. Test the webhook:
   ```bash
   curl -X POST https://your-domain.example.com/api/webhook/batch \
     -H "Content-Type: application/json" \
     -d '{"secret":"your-secret","account_number":12345}'
   ```

### Option B: Home Assistant NGINX Add-on

In your NGINX config (`/share/nginx/nginx.conf`):

```nginx
server {
    listen 443 ssl;
    server_name your-domain.example.com;

    ssl_certificate /ssl/fullchain.pem;
    ssl_certificate_key /ssl/privkey.pem;

    location / {
        proxy_pass http://localhost:7842;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option C: Cloudflare Tunnel (Zero Port Forwarding)

1. Install **Cloudflare Tunnel** on your Home Assistant host
2. Create a tunnel pointing `your-domain.example.com` → `localhost:7842`
3. No port forwarding on your router required

### Option D: Port Forwarding (Simple)

On your router, forward:
- **External Port:** `7842` (or `443` if using SSL at router level)
- **Internal IP:** Your Home Assistant IP
- **Internal Port:** `7842`

> ⚠️ **Note:** MT4 only supports HTTPS for WebRequest. Use a reverse proxy with SSL (Options A, B, or C) for production.

---

## 🤖 MT4 EA Setup

### Installation

1. Download `HA_TradeSync_MT4_v4.4.mq4` from the **Releases** section
2. In MT4: **File → Open Data Folder → MQL4 → Experts**
3. Copy the `.mq4` file into the `Experts` folder
4. Restart MT4 or press **Refresh** in the Navigator panel
5. Compile: double-click the EA in the Navigator → **Compile** in MetaEditor

### Allow WebRequest URL

**This step is critical!** MT4 blocks all external requests by default.

1. Go to **Tools → Options → Expert Advisors**
2. Check ✅ **Allow WebRequest for listed URL**
3. Add your webhook URL:
   ```
   https://your-domain.example.com
   ```
4. Click **OK**

### Attach to Chart

1. Open a chart (any symbol, e.g. EURUSD H1)
2. Drag the EA from Navigator onto the chart
3. In the **Inputs** tab, configure:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `WebhookURL` | Your full webhook endpoint | `https://your-domain.example.com/api/webhook/batch` |
| `SecretKey` | Must match add-on config | `your-strong-secret-key-here` |
| `EAName` | Display name in dashboard | `Perceptrader AI` |
| `Category` | Account type | `live` / `copy` / `demo` |
| `HistoryDays` | Days of history to send | `365` |
| `UpdateSec` | How often to sync (seconds) | `10` |

4. Enable **AutoTrading** (green button in toolbar)
5. Allow **DLL imports** if prompted

### Verify

Check the **Experts** tab in MT4 terminal:
```
✓ Sent: 299 trades, 1 open
```

---

## 🤖 MT5 EA Setup

### Installation

1. Download `HA_TradeSync_MT5_v4.4.mq5`
2. In MT5: **File → Open Data Folder → MQL5 → Experts**
3. Copy the `.mq5` file and restart MT5

### Allow WebRequest URL

1. **Tools → Options → Expert Advisors**
2. Check ✅ **Allow WebRequest for listed URL**
3. Add: `https://your-domain.example.com`

### Parameters

Same as MT4 (see table above). Attach to any chart and verify in the **Experts** tab.

---

## 💱 Deposit Detection

The EA automatically detects deposits and withdrawals based on broker-specific formats:

| Broker | Format | Detection Method |
|--------|--------|-----------------|
| LiteFinance | `DPST-IT-5208013: USD 2000.00` | Comment starts with `DPST-` |
| LiteFinance | `VPS-PAYMENT-17835` | Comment starts with `VPS-` |
| Black Bull | `Transfer_from_206835_Wallet` | Comment contains `Transfer_from_` AND `_Wallet` |
| Most brokers | — | OrderType 6 (Balance) or 7 (Credit) |

> **Note:** The EA intentionally avoids generic "balance" keyword matching because some EA trade comments contain the word "balanced" (e.g., `#17164000 XAU Balanced[tp]`).

---

## 📊 Dashboard Guide

### Overview Page

| Metric | Description |
|--------|-------------|
| **Balance** | Total balance across Live + Copy accounts (in selected currency) |
| **Profit** | Total realized + floating profit, Live + Copy only |
| **Accounts** | Total number of registered accounts |
| **Trades** | Total closed trades, Live + Copy only |

Demo accounts are excluded from all overview totals.

### Account Table Columns

| Column | Description |
|--------|-------------|
| Deposits | Total deposits detected |
| Balance | Current account balance |
| Profit | Total net profit (trades only) |
| Gain | `Profit / Deposits × 100` |
| Win% | Percentage of winning trades |
| PF | Profit Factor (`Gross Profit / Gross Loss`) |
| DD | Maximum Drawdown (peak-to-trough) |
| Days | Days since first trade |

### Detail Page

Click any account name to open the detail view:

- **Period tabs:** Today / This Week / This Month / This Year / All Time
- All metrics recalculate for the selected period
- **Charts:** Equity curve, Win/Loss donut, Monthly bar chart
- **Trade history:** Full sortable table for the selected period

### Currency Conversion

Open ⚙️ Settings to switch between USD and EUR. Rates are fetched live from [frankfurter.app](https://frankfurter.app) and refreshed every hour.

Every value shows the primary currency large with the equivalent in the other currency shown small below:
```
€2,517.93
≈ $2,985
```

---

## 🔧 Troubleshooting

### EA shows "✗ Add URL to allowed list!"

→ Go to MT4/MT5: **Tools → Options → Expert Advisors** and add your full webhook URL.

### Dashboard shows 0 trades for an account

→ Check the MT4 **Experts** tab for error messages. Common causes:
- Wrong `SecretKey` (must match add-on config exactly)
- WebRequest URL not in allowed list
- EA not attached to chart / AutoTrading disabled

### Deposits showing $0 or wrong amount

→ The EA logs all detected balance operations. Check MT4 **Experts** tab:
```
BalanceOp: Transfer_from_206835_Wallet = $2000.00
Deposits: $2000.00
```
If no `BalanceOp` lines appear, your broker uses an unsupported deposit format. Please [open an issue](../../issues) with your broker name and deposit comment format.

### Wrong profit/gain values

→ Ensure your broker's deposit is correctly detected. If `Deposits = $0`, the gain calculation will be incorrect. You can manually override the deposit amount in ⚙️ Settings → Account → Deposits field.

### Currency conversion shows wrong values

→ The rate is fetched from `frankfurter.app`. If your network blocks this URL, conversion will not work and values will remain in USD.

---

## 📁 Repository Structure

```
ea-dashboard/
├── config.yaml              # Add-on metadata and config schema
├── Dockerfile               # Container definition
├── run.sh                   # Startup script
├── requirements.txt         # Python dependencies
├── rootfs/
│   └── app/
│       ├── main.py          # Flask backend API
│       └── static/
│           └── index.html   # Single-page frontend
└── mt-experts/
    ├── HA_TradeSync_MT4_v4.4.mq4   # MT4 Expert Advisor
    └── HA_TradeSync_MT5_v4.4.mq5   # MT5 Expert Advisor
```

---

## 🔌 API Reference

The backend exposes these endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/accounts` | All accounts with computed stats |
| `GET` | `/api/accounts/{id}` | Single account detail + equity curve |
| `PUT` | `/api/accounts/{id}` | Update account (deposit override) |
| `DELETE` | `/api/accounts/{id}` | Remove account |
| `GET` | `/api/live-trades` | Currently open positions (Live+Copy) |
| `GET` | `/api/today-trades` | Trades closed today (Live+Copy) |
| `POST` | `/api/webhook/batch` | EA sends data here |

### Webhook Payload Example

```json
{
  "secret": "your-secret",
  "account_number": 12345678,
  "ea_name": "Perceptrader AI",
  "broker": "LiteFinance Global LLC",
  "platform": "MT4",
  "category": "live",
  "current_balance": 2984.99,
  "current_equity": 2981.88,
  "total_deposits": 2054.81,
  "total_withdrawals": 15.00,
  "currency": "USD",
  "leverage": 300,
  "trades": [
    {
      "trade_id": 72385933,
      "symbol": "NZDUSD",
      "type": "BUY",
      "lots": 0.01,
      "open_price": 0.56120,
      "close_price": 0.56190,
      "open_time": "2026.01.15 09:00",
      "close_time": "2026.01.15 11:30",
      "profit": 7.00,
      "swap": -0.02,
      "commission": 0.00
    }
  ],
  "open_trades": [
    {
      "trade_id": 72385999,
      "symbol": "USDCAD",
      "type": "SELL",
      "lots": 0.01,
      "open_price": 1.44200,
      "current_price": 1.44450,
      "open_time": "2026.01.17 14:22",
      "profit": -3.40
    }
  ]
}
```

---

## 🔒 Security

- All webhook requests are validated against the `secret_key`
- Use HTTPS (via reverse proxy) to encrypt data in transit
- The add-on only listens on your local network by default
- No external services receive your trading data (only FX rates from frankfurter.app)

---

## 🗺️ Roadmap

- [ ] Push notifications (Home Assistant alerts when DD threshold hit)
- [ ] More broker deposit formats
- [ ] CSV/Excel export
- [ ] Telegram / webhook alerts for trade events
- [ ] Dark/Light theme toggle

---

## 🤝 Contributing

Pull requests welcome! Please:
1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push and open a Pull Request

For broker-specific deposit format support, please open an issue and include your MT4 statement HTML excerpt showing the balance operation row.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
