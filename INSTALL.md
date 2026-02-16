# Installation Guide

## Step 1: Add Repository
Settings → Add-ons → ⋮ → Repositories
Add: https://github.com/ArrestedOps/ha-ea-dashboard

## Step 2: Install
Find "EA Trading Dashboard" → Install (5-10 min)

## Step 3: Configure
Configuration tab:
webhook_secret: "your_secret_here"

## Step 4: Install MT Expert Advisor
Copy HA_TradeSync_MT4.ex4 to /MQL4/Experts/ (or MT5 version)
Restart MT4/MT5
Drag EA onto chart
Configure:
- Webhook URL: http://YOUR_HA_IP:8099/api/webhook/trade
- Secret: your_secret_here
- EA Name: My EA
- Category: live

## Step 5: Done!
Dashboard shows trades automatically!
