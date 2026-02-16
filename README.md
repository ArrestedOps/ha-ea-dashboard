# EA Trading Dashboard v2.0

**Professional MetaTrader statistics dashboard with LIVE webhook integration!**

## 🎉 NEW in v2.0

✅ **Direct MT4/MT5 Integration** - No MetaAPI needed!  
✅ **Auto-Create EAs** - New accounts appear automatically  
✅ **Category System** - Live, Demo, Copy, Challenge  
✅ **Manual Management** - Edit/Delete EAs in dashboard  
✅ **Real-time Updates** - Instant when trades close  

---

## 🚀 Quick Start

### 1. Install Add-on

```
Settings → Add-ons → Add-on Store → ⋮ → Repositories
Add: https://github.com/ArrestedOps/ha-ea-dashboard
Install "EA Trading Dashboard"
```

### 2. Configure (Optional)

```yaml
webhook_secret: "my_secret_key_123"  # Optional but recommended
```

### 3. Install Expert Advisor

**MT4:**
1. Copy `HA_TradeSync_MT4.ex4` to `/MQL4/Experts/`
2. Restart MT4
3. Drag EA onto any chart

**MT5:**
1. Copy `HA_TradeSync_MT5.ex5` to `/MQL5/Experts/`
2. Restart MT5
3. Drag EA onto any chart

### 4. Configure EA

```
Webhook URL: http://YOUR_HA_IP:8099/api/webhook/trade
Secret Key: my_secret_key_123  (same as add-on)
EA Name: Perceptrader AI
Category: live  (or: demo, copy, challenge)
```

### 5. Done!

EA sends trades → Dashboard updates automatically! 🎉

---

## 📊 Features

### Categories

- 🟢 **Live** - Real money trading
- 🟠 **Demo** - Practice accounts  
- 🔵 **Copy** - Copy trading accounts
- 🟣 **Challenge** - FTMO/Prop firm challenges

### Dashboard

- Overview page with all EAs
- Detail page per EA with full stats
- Filter by category
- Manual EA management
- Real-time updates

### Statistics

- Balance tracking
- Win rate
- Profit factor  
- Drawdown analysis
- Monthly returns
- Trade history

---

## 🔧 Advanced Configuration

### Webhook Security

**Highly Recommended:**

```yaml
webhook_secret: "use_a_long_random_string_here_987654321"
```

Then set same secret in MT EA settings!

### Multiple EAs

Run multiple EAs - they auto-appear in dashboard:

```
Chart 1: Perceptrader AI (live)
Chart 2: Gold Scalper (demo)
Chart 3: FTMO Bot (challenge)
```

Each gets its own card automatically!

### Edit/Delete EAs

Dashboard → Click EA card → Settings icon → Edit/Delete

---

## 📝 EA Parameters Explained

| Parameter | Description | Example |
|-----------|-------------|---------|
| Webhook URL | Your HA add-on URL | `http://192.168.1.100:8099/api/webhook/trade` |
| Secret Key | Security token (optional) | `my_secret_123` |
| EA Name | Display name in dashboard | `Perceptrader AI` |
| Category | Account type | `live`, `demo`, `copy`, `challenge` |
| Send History | Send past trades on start | `true` |
| History Days | Days of history to send | `90` |

---

## 🐛 Troubleshooting

### EA not sending trades

1. Check MT4/MT5 Journal for errors
2. Verify Webhook URL is correct
3. Test URL in browser: `http://YOUR_IP:8099/api/status`
4. Check firewall allows port 8099
5. Verify "Allow WebRequest for listed URL" in MT Tools → Options

### Trades not appearing

1. Check add-on logs
2. Verify secret keys match
3. Try without secret first
4. Check EA is running (smiley face icon)

### Wrong category

Dashboard → EA card → Edit → Change category → Save

---

## 🔐 Security

- Use webhook secret in production
- Run HA on local network only
- Don't expose port 8099 to internet
- EAs only send data, never receive commands

---

## 📖 API Endpoints

```
GET  /api/accounts - List all accounts
GET  /api/accounts/:id - Get account details
PUT  /api/accounts/:id - Update account
DELETE /api/accounts/:id - Archive account
POST /api/webhook/trade - Receive trades (EA uses this)
```

---

## 💡 Tips

- Start with demo account first
- Use descriptive EA names
- Check logs if issues occur
- One EA per chart is enough
- Categories help organize multiple accounts

---

## 📄 Version History

**v2.0.0** - Direct MT4/MT5 integration with webhooks  
**v1.0.0** - Initial demo version

---

## 🙏 Support

**Issues:** https://github.com/ArrestedOps/ha-ea-dashboard/issues  
**Logs:** Settings → Add-ons → EA Dashboard → Log

---

**Happy Trading! 📈💰**
