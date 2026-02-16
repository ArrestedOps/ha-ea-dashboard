# 🚀 EA Trading Dashboard v3.0 - Installation Guide

## Schnell-Installation (5 Schritte)

### **1️⃣ GitHub Repository aktualisieren**

**Option A: Komplette Neu-Installation (Empfohlen)**
1. Altes Repository löschen (falls vorhanden)
   ```
   https://github.com/ArrestedOps/ha-ea-dashboard/settings
   → Delete this repository
   ```

2. Neues Repository erstellen
   ```
   https://github.com/new
   Name: ha-ea-dashboard
   Public ✅
   Create repository
   ```

3. Dateien hochladen
   - Entpacke `ea-dashboard-v3.0-FINAL.tar.gz`
   - Gehe IN den Ordner `ea-dashboard-v3.0/`
   - Markiere ALLE Dateien (Strg+A)
   - Drag & Drop auf GitHub
   - Commit: "v3.0 - Professional Dashboard with Live Trades"

**Option B: Update via Git (Fortgeschritten)**
```bash
git clone https://github.com/ArrestedOps/ha-ea-dashboard.git
cd ha-ea-dashboard
# Entpacke v3.0 files hier
git add .
git commit -m "Update to v3.0"
git push
```

---

### **2️⃣ Home Assistant Update**

```
Settings → Add-ons → Add-on Store
⋮ → Check for updates

Oder: Settings → System → Supervisor
→ Reload Supervisor
```

**Dann:**
```
Settings → Add-ons → EA Trading Dashboard
→ "Update available to v3.0.0"
→ Update klicken
→ Warten (2-5 Min)
```

---

### **3️⃣ Konfiguration (Optional)**

```yaml
# Configuration Tab:
webhook_secret: "mein_super_sicherer_schluessel_2026"
```

**Dann:**
- Save
- Start (falls gestoppt)

---

### **4️⃣ MT4/MT5 EA konfigurieren**

**Wenn du NEUE EAs startest oder URLs änderst:**

```
MT4 EA Settings:
├─ WebhookURL: http://api.dobko.it/api/webhook/trade
├─ SecretKey: mein_super_sicherer_schluessel_2026
├─ EAName: Perceptrader AI
├─ Category: live
└─ SendHistory: true
```

**Bestehende EAs:** Laufen weiter ohne Änderung! ✅

---

### **5️⃣ Erste Schritte nach Installation**

1. **Dashboard öffnen**
   ```
   Sidebar → EA Dashboard
   ```

2. **Settings öffnen** (⚙️ Button rechts unten)

3. **Währung einstellen**
   ```
   Display Currency: USD / EUR / BOTH
   ```

4. **Konten konfigurieren**
   Für jedes Konto:
   - Name anpassen
   - Broker eintragen
   - **Deposit manuell setzen** (für korrekten Drawdown!)
   - Kategorie prüfen (Live/Copy/Demo)
   - Währung setzen (USD/EUR)
   - Speichern

5. **Fertig!** 🎉

---

## ⚙️ Deposit (Startkapital) richtig eintragen

### **Warum wichtig?**
Ohne korrektes Deposit ist der **Drawdown ungenau**!

### **So geht's:**

1. **Settings öffnen** (⚙️)
2. **Konto finden** (z.B. "Perceptrader AI")
3. **Deposit-Feld:** Trage Startkapital ein
   ```
   Beispiel: 2000.00
   ```
4. **Speichern**
5. **Dashboard refreshen** → Drawdown jetzt korrekt! ✅

### **Deposit-Werte herausfinden:**

**Option A:** Aus MyFxBook kopieren
```
MyFxBook → Account → Statistics
→ "Einlagen" oder "Deposit"
```

**Option B:** Aus MT4 History
```
MT4 → Account History
→ Älteste Balance
→ Das ist dein Deposit
```

**Option C:** Du weißt es selbst 😊
```
Wie viel hast du eingezahlt?
```

---

## 🔧 Nach dem Update: Checkliste

### **✅ Sofort prüfen:**

- [ ] Dashboard lädt ohne Fehler
- [ ] Live Trades Tab funktioniert
- [ ] Heute Tab funktioniert
- [ ] Tabellen zeigen Konten
- [ ] Sortieren funktioniert (Klick auf Spalte)
- [ ] Settings Modal öffnet
- [ ] Konten bearbeitbar

### **✅ Settings konfigurieren:**

- [ ] Display Currency gesetzt
- [ ] Deposit für alle Konten eingetragen
- [ ] Broker-Namen gesetzt
- [ ] Kategorien korrekt (Live/Copy/Demo)
- [ ] Währungen pro Konto gesetzt

### **✅ Testen:**

- [ ] Trade schließen → Erscheint in "Heute"
- [ ] Sortierung testen (Klick auf Spalten)
- [ ] Edit-Button (✏️) funktioniert
- [ ] Währungsumrechnung korrekt

---

## 🐛 Troubleshooting

### **Update erscheint nicht?**
```
Settings → System → Supervisor
→ Reload Supervisor
→ Warte 30s
→ Refresh Browser (F5)
```

### **Alte Version läuft noch?**
```
Settings → Add-ons → EA Dashboard
→ Info Tab
→ Check version: Sollte "3.0.0" sein
→ Falls nicht: Rebuild oder Reinstall
```

### **Dashboard zeigt Demo-Daten?**
```
Browser Cache leeren:
Strg + Shift + Delete
→ Cached images and files ✅
→ Clear data
→ Dashboard neu laden
```

### **Deposit-Feld leer?**
```
Normal! Das musst du manuell eintragen.
EA kann Deposit nicht automatisch erkennen.
```

### **Drawdown 0%?**
```
Deposit fehlt!
Settings → Konto → Deposit eintragen → Speichern
```

### **Trades erscheinen nicht?**
```
1. Check MT EA Journal
2. WebRequest URL erlaubt?
3. API Test: http://api.dobko.it/api/status
4. Add-on Logs prüfen
```

---

## 📱 Mobile Nutzung

### **Installation als App (PWA):**

**Android Chrome:**
1. Dashboard öffnen
2. ⋮ → "Add to Home screen"
3. Fertig! App-Icon auf Homescreen

**iOS Safari:**
1. Dashboard öffnen
2. Share → "Add to Home Screen"
3. Fertig!

### **Mobile Features:**
- ✅ Touch-optimiert
- ✅ Horizontal-Scroll für Tabellen
- ✅ Fixed Dates (kein "Invalid Date")
- ✅ Responsive Design
- ✅ Schnell & flüssig

---

## 🔄 Downgrade zu v2.x (Falls nötig)

Falls v3.0 Probleme macht:

```
Settings → Add-ons → EA Dashboard
→ Uninstall
→ Repository entfernen
→ Altes Repository hinzufügen
→ v2.x installieren
```

**Daten bleiben erhalten!** ✅

---

## 💡 Pro-Tips nach Installation

### **1. Deposit sofort eintragen**
Spare dir später Arbeit - trage Deposits jetzt ein!

### **2. Kategorien nutzen**
Sortiere deine Accounts:
- 🟢 Live → Echtgeld
- 🔵 Copy → Copy-Trading
- 🟠 Demo → Test-Accounts

### **3. Währung konsequent**
Setze für JEDES Konto die richtige Währung!

### **4. Broker-Namen**
Trage lesbare Broker ein:
- ✅ "IC Markets"
- ❌ "ICMarketsEUSC-Live"

### **5. Display Currency**
Nutze "BOTH" wenn du gemischte Konten hast!

---

## 📊 Features optimal nutzen

### **Live Trades Monitor:**
- Prüfe regelmäßig offene Positionen
- Beobachte P/L Entwicklung
- Erkenne problematische Trades früh

### **Today's Trades:**
- Schneller Tages-Performance Check
- Vergleiche mit Zielen
- Spot Pattern

### **Sortierung:**
- Klick auf "GAIN %" → Beste/Schlechteste zuerst
- Klick auf "TRADES" → Aktivste Accounts
- Klick auf "PF" → Qualität-Ranking

### **Settings:**
- Regelmäßig Deposit aktualisieren bei Ein/Auszahlungen
- Broker-Infos pflegen
- Alte Accounts löschen

---

## 🎯 Nächste Schritte

1. ✅ Installation abgeschlossen
2. ✅ Settings konfiguriert
3. ✅ Deposit eingetragen
4. ✅ Kategorien gesetzt

**Jetzt:**
- 📊 Dashboard beobachten
- 📈 Performance tracken
- 💰 Trading optimieren
- 🚀 Erfolg haben!

---

**Support:** https://github.com/ArrestedOps/ha-ea-dashboard/issues  
**Version:** 3.0.0  
**Datum:** 16. Februar 2026

---

**Happy Trading! 📈💰**
