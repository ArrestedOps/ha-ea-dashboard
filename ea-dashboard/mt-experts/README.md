# MT4/MT5 Expert Advisor — Installations- und Konfigurationsanleitung

## 📁 Dateien

- `HA_TradeSync_MT4_v5.0.mq4` — MetaTrader 4 Expert Advisor
- `HA_TradeSync_MT5_v5.0.mq5` — MetaTrader 5 Expert Advisor

---

## 🚀 Installation

### MT4 Installation

1. **Datei kopieren:**
   ```
   HA_TradeSync_MT4_v5.0.mq4
   → C:\Users\[Username]\AppData\Roaming\MetaTrader 4\MQL4\Experts\
   ```

2. **MetaEditor öffnen** (F4 in MT4)

3. **Datei kompilieren:**
   - Datei öffnen
   - F7 drücken (Compile)
   - Keine Fehler = ✓ Fertig

4. **MT4 neu starten**

### MT5 Installation

1. **Datei kopieren:**
   ```
   HA_TradeSync_MT5_v5.0.mq5
   → C:\Users\[Username]\AppData\Roaming\MetaTrader 5\MQL5\Experts\
   ```

2. **MetaEditor öffnen** (F4 in MT5)

3. **Datei kompilieren:**
   - Datei öffnen
   - F7 drücken (Compile)
   - Keine Fehler = ✓ Fertig

4. **MT5 neu starten**

---

## ⚙️ Konfiguration

### 1. WebRequest URL freigeben

**WICHTIG:** MT4/MT5 muss die Webhook-URL erlauben!

1. **Tools → Options → Expert Advisors**
2. **"Allow WebRequest for listed URL" aktivieren**
3. **URL hinzufügen:**
   ```
   http://homeassistant.local:8099/api/webhook
   ```
   oder deine spezifische IP:
   ```
   http://192.168.1.100:8099/api/webhook
   ```

4. **OK klicken**

### 2. EA auf Chart ziehen

1. **Navigator öffnen** (Ctrl+N)
2. **Expert Advisors → HA_TradeSync_MT4_v5.0** (oder MT5)
3. **Auf beliebigen Chart ziehen** (z.B. EURUSD M15)

### 3. EA-Parameter einstellen

Im EA-Dialog erscheinen folgende Parameter:

---

#### 📌 **Webhook URL**
```
http://homeassistant.local:8099/api/webhook
```
**Beschreibung:** URL deines Home Assistant Dashboards

**Beispiele:**
- Lokales Netzwerk: `http://192.168.1.100:8099/api/webhook`
- DuckDNS: `https://your-domain.duckdns.org:8099/api/webhook`
- Tailscale: `http://100.x.x.x:8099/api/webhook`

---

#### 📝 **EA Name**
```
Perceptrader AI
```
**Beschreibung:** Name deines Expert Advisors (frei wählbar)

**Wichtig:**
- Dieser Name erscheint im Dashboard
- Sollte aussagekräftig sein (z.B. "Waka Waka Gold", "Golden Pickaxe", etc.)
- Pro Account GLEICHER Name = gleicher Account im Dashboard
- Pro Account ANDERER Name = NEUER Account im Dashboard ❗

**Beispiele:**
- `Perceptrader AI`
- `Waka Waka EURUSD`
- `Golden Pickaxe XAUUSD`
- `My Custom EA`

---

#### 🎯 **Account Category** ⭐ NEU!
```
Dropdown-Auswahl:
- Live Account     🟢
- Copy Trading     🔵
- Demo Account     🟠 (Standard)
```

**Beschreibung:** Kategorie des Trading-Accounts

**Wichtig:**
- **Live:** Echtes Geld, wird im Dashboard als LIVE angezeigt
- **Copy:** Copy-Trading (z.B. von myfxbook, Telegram-Signalen), separate Kategorie
- **Demo:** Demo/Test-Account (Standard)

**Im Dashboard:**
- Accounts werden nach Kategorie gruppiert
- Filter-Tabs: "Alle" | "🟢 Live" | "🔵 Copy" | "🟠 Demo"
- Separate Live/Today-Boxen pro Kategorie

**Beispiele:**
- ICMarkets Live Account → `Live Account`
- myfxbook Copy → `Copy Trading`
- Backtesting → `Demo Account`

---

#### 📅 **Start Date** ⭐ NEU!
```
Datumsauswahl: z.B. 2025.01.15 00:00
```

**Beschreibung:** Startdatum für Berechnungen (Days Running, Performance, etc.)

**Wichtig:**
- Dashboard berechnet "Days Running" ab diesem Datum
- Nur Trades NACH diesem Datum werden berücksichtigt
- Sollte das Datum sein, an dem du mit diesem EA LIVE gegangen bist

**Warum?**
- Du hast vielleicht vorher Demo-Trades, die nicht zählen sollen
- Du willst Performance ab einem bestimmten Punkt messen
- Bei Account-Reset/Re-Deposit kannst du neu starten

**Beispiele:**
- Heute live gegangen: `2025.03.08 00:00`
- Vor 2 Wochen gestartet: `2025.02.22 00:00`
- Jahresbeginn: `2025.01.01 00:00`

**Standard:** `2025.01.01 00:00`

---

#### ⏱️ **Webhook Interval**
```
60 (Sekunden)
```

**Beschreibung:** Wie oft werden Daten gesendet?

**Empfohlene Werte:**
- **60 Sekunden** (Standard) — Guter Kompromiss
- **30 Sekunden** — Für schnelle Scalper
- **120 Sekunden** — Für Swing Trader
- **300 Sekunden** (5 Min) — Minimale Updates

**Wichtig:**
- Je kleiner der Wert, desto mehr Netzwerk-Traffic
- Dashboard refresht sowieso nur alle 10 Sekunden
- 60 Sekunden ist für 99% der Fälle perfekt

---

### 4. EA aktivieren

1. **"Allow live trading" aktivieren** ✅
2. **"Allow DLL imports" NICHT nötig** (WebRequest ist eingebaut)
3. **OK klicken**

### 5. Überprüfung

**Im MT4/MT5 Experts-Tab sollte erscheinen:**
```
=== EA Dashboard v5.0 Initialized ===
EA Name: Perceptrader AI
Category: live
Start Date: 2025.01.15
Webhook URL: http://homeassistant.local:8099/api/webhook
Webhook Interval: 60 seconds
✓ Webhook sent successfully
```

**Bei Fehler:**
```
ERROR: WebRequest failed. Error code: 4060
Make sure URL is in Tools -> Options -> Expert Advisors -> Allow WebRequest for:
http://homeassistant.local:8099/api/webhook
```
→ URL noch nicht freigegeben! Siehe Schritt 1.

---

## 🎨 Dashboard-Ansicht

### Nach erfolgreichem Setup siehst du:

**Account Card:**
```
┌─────────────────────────────────────┐
│ Perceptrader AI           ●Online   │
│ #827903  [LIVE]                     │ ← Category als Badge
├─────────────────────────────────────┤
│ Balance    $5,234.50                │
│ Profit     +$234.20                 │
│ Gain       +4.68%                   │
│ Trades     45                       │
├─────────────────────────────────────┤
│ Win: 65.5%              12d         │ ← Days seit Start Date
└─────────────────────────────────────┘
```

**Filter Tabs:**
```
[Alle] [🟢 Live] [🔵 Copy] [🟠 Demo]
```
Klicke auf eine Kategorie → nur diese Accounts werden angezeigt

---

## 🔧 Troubleshooting

### Webhook wird nicht gesendet

**Problem:** Keine Logs im MT4/MT5 Experts-Tab

**Lösung:**
1. EA aktiviert? ("Smiling face" Icon im Chart oben rechts)
2. "Allow live trading" aktiviert?
3. EA neu auf Chart ziehen

---

### Error 4060 — WebRequest Failed

**Problem:** `ERROR: WebRequest failed. Error code: 4060`

**Lösung:**
1. Tools → Options → Expert Advisors
2. "Allow WebRequest for listed URL" ✅
3. URL EXAKT kopieren (mit http://)
4. MT4/MT5 neu starten

---

### Keine Daten im Dashboard

**Problem:** Dashboard bleibt leer trotz "✓ Webhook sent successfully"

**Lösung:**
1. Dashboard-URL öffnen: `http://homeassistant.local:8099`
2. F12 → Console → Fehler?
3. API testen: `http://homeassistant.local:8099/api/accounts`
4. Backend-Logs prüfen (Home Assistant Add-on Logs)

---

### Account erscheint mehrfach

**Problem:** Gleicher Account wird mehrfach angezeigt

**Ursache:** **EA Name wurde geändert!**

**Lösung:**
- Pro Account = GLEICHER EA Name verwenden
- Accounts werden NUR nach `account_number` gematcht
- Aber EA Name sollte konsistent bleiben

**Fix:**
1. Im Dashboard: Duplikat-Account löschen
2. Im MT4/MT5: EA Name korrigieren
3. EA neu starten

---

### Days Running ist falsch

**Problem:** "Days Running" zeigt falsche Anzahl

**Ursache:** Start Date falsch gesetzt

**Lösung:**
1. EA Parameter öffnen
2. Start Date auf korrektes Datum setzen
3. EA neu starten
4. Dashboard refreshen (F5)

**Wichtig:**
- Start Date wird nur EINMAL beim ersten Webhook gespeichert
- Spätere Änderungen werden NICHT überschrieben
- Falls korrigieren: Account im Dashboard löschen, EA neu starten

---

## 📊 Webhook-Format (Technical)

**Was wird gesendet:**
```json
{
  "account_number": 827903,
  "ea_name": "Perceptrader AI",
  "broker": "ICMarkets",
  "platform": "MT4",
  "category": "live",
  "currency": "USD",
  "current_balance": 5234.50,
  "total_deposits": 5000,
  "leverage": 500,
  "start_date": "2025-01-15T00:00:00",
  "trades": [
    {
      "trade_id": 12345,
      "symbol": "EURUSD",
      "type": "BUY",
      "volume": 0.1,
      "open_price": 1.08543,
      "close_price": 1.08650,
      "profit": 10.70,
      "open_time": "2025-03-08T10:00:00",
      "close_time": "2025-03-08T11:30:00"
    }
  ],
  "open_trades": [
    {
      "trade_id": 12346,
      "symbol": "GBPUSD",
      "type": "SELL",
      "volume": 0.5,
      "open_price": 1.26450,
      "profit": -5.30,
      "open_time": "2025-03-08T14:00:00"
    }
  ]
}
```

---

## 💡 Best Practices

### Pro EA = Eine Instance

- **Pro Expert Advisor = EIN HA_TradeSync EA**
- Mehrere EAs auf verschiedenen Charts → Mehrere HA_TradeSync Instances
- GLEICHER Account, GLEICHER EA Name = EIN Dashboard-Account

**Beispiel:**
```
Chart 1: EURUSD + Perceptrader AI + HA_TradeSync (EA Name: "Perceptrader AI")
Chart 2: XAUUSD + Golden Pickaxe + HA_TradeSync (EA Name: "Golden Pickaxe")
Chart 3: GBPUSD + Waka Waka + HA_TradeSync (EA Name: "Waka Waka")

→ Dashboard zeigt 3 separate Accounts
```

### Startdatum sinnvoll wählen

- **Live-Start:** Datum, als du LIVE gegangen bist
- **Nach Deposit:** Nach größerem Deposit neu starten
- **Nach Reset:** Bei Account-Reset (z.B. nach Drawdown)

### Category richtig setzen

- **Live:** NUR für echtes Geld
- **Copy:** NUR für Copy-Trading
- **Demo:** Alles andere

→ Bessere Übersicht im Dashboard!

---

## 🆕 Neu in v5.0

✅ **Dropdown für Category** (Live/Copy/Demo)  
✅ **Startdatum** statt automatische Days  
✅ **start_date** wird in DB gespeichert  
✅ **Days Running** ab Start Date berechnet  
✅ **Kategorie-Filter** im Dashboard  
✅ **Separate Live/Today Boxen** pro Category  

---

## 📞 Support

Bei Problemen:
1. Logs im MT4/MT5 Experts-Tab prüfen
2. Dashboard API-Docs öffnen: `/docs`
3. Backend-Logs prüfen (Home Assistant)
4. GitHub Issues öffnen

---

**Viel Erfolg mit deinem Trading! 📈**
