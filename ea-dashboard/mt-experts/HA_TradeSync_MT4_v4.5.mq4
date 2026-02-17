//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v4.5.mq4 |
//|  DEFINITIVE FIX: Precise comment pattern matching               |
//|  Black Bull: "Transfer_from_XXXXX_Wallet" = Deposit             |
//|  Black Bull Trade: "#17164000 XAU Balanced[tp]" = REAL TRADE    |
//+------------------------------------------------------------------+
#property version "4.50"
#property strict

input string WebhookURL  = "http://api.dobko.it/api/webhook/batch";
input string SecretKey   = "your_secret";
input string EAName      = "My EA";
input string Category    = "live";   // live / copy / demo
input int    HistoryDays = 365;
input int    UpdateSec   = 10;

datetime lastSent = 0;
double   gDeposits = 0;
double   gWithdraw = 0;

int OnInit()
{
   Print("=== EA Dashboard MT4 v4.5.0 ===");
   Print("Broker: ", AccountCompany());
   ScanHistory();
   SendData();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r) {}
void OnTick()
{
   if(TimeCurrent() - lastSent >= UpdateSec)
   {
      SendData();
      lastSent = TimeCurrent();
   }
}

//--------------------------------------------------------------------
// IsBalanceOp: ONLY matches known deposit/withdrawal patterns
// Does NOT use generic "balance" keyword - that appears in EA comments!
//--------------------------------------------------------------------
bool IsBalanceOp(int idx)
{
   if(!OrderSelect(idx, SELECT_BY_POS, MODE_HISTORY)) return false;

   // 1) OrderType 6=Balance, 7=Credit (LiteFinance & most brokers)
   int ot = OrderType();
   if(ot == 6 || ot == 7) return true;

   // 2) Comment pattern matching - SPECIFIC patterns only!
   string cmt = OrderComment();
   string cLow = cmt;
   StringToLower(cLow);

   // Black Bull: "Transfer_from_XXXXXXX_Wallet"
   // Must contain BOTH "transfer_from_" AND "_wallet"
   if(StringFind(cLow, "transfer_from_") >= 0 && StringFind(cLow, "_wallet") >= 0)
      return true;

   // LiteFinance deposit: "DPST-IT-XXXXXXX: USD xxx"
   if(StringLen(cLow) > 4 && StringSubstr(cLow, 0, 5) == "dpst-")
      return true;

   // LiteFinance withdrawal: "VPS-PAYMENT-XXXXX"
   if(StringLen(cLow) > 3 && StringSubstr(cLow, 0, 4) == "vps-")
      return true;

   // Generic keywords (safe - these won't appear in EA trade comments)
   if(StringFind(cLow, "withdrawal") >= 0) return true;
   if(StringFind(cLow, "credit in") >= 0) return true;

   // 3) No symbol AND round profit >= 100 (safest heuristic)
   if(OrderSymbol() == "" && OrderSwap() == 0.0 && OrderCommission() == 0.0)
   {
      double p = OrderProfit();
      if(MathAbs(p) >= 100 && p == MathRound(p)) return true;
   }

   return false;
}

//--------------------------------------------------------------------
void ScanHistory()
{
   gDeposits = 0;
   gWithdraw = 0;
   double tradeProfit = 0;
   int realTrades = 0, balOps = 0;
   datetime from = TimeCurrent() - (HistoryDays * 86400);
   int n = OrdersHistoryTotal();

   for(int i = 0; i < n; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < from) continue;

      if(IsBalanceOp(i))
      {
         double amt = OrderProfit();
         if(amt > 0) gDeposits += amt;
         else gWithdraw += MathAbs(amt);
         balOps++;
         Print("BalanceOp: ", OrderComment(), " = $", DoubleToString(amt, 2));
      }
      else if(OrderType() <= 1)
      {
         tradeProfit += OrderProfit() + OrderSwap() + OrderCommission();
         realTrades++;
      }
   }

   Print("=== SCAN RESULT ===");
   Print("Broker: ", AccountCompany());
   Print("Real Trades: ", realTrades);
   Print("Balance Ops: ", balOps);
   Print("Deposits: $", DoubleToString(gDeposits, 2));
   Print("Withdrawals: $", DoubleToString(gWithdraw, 2));
   Print("Trade Profit: $", DoubleToString(tradeProfit, 2));
   Print("===================");
}

//--------------------------------------------------------------------
string EJ(string s) { StringReplace(s, "\"", "'"); return s; }

void SendData()
{
   datetime from = TimeCurrent() - (HistoryDays * 86400);
   string j = "{";
   j += "\"secret\":\""          + SecretKey + "\",";
   j += "\"account_number\":"    + IntegerToString(AccountNumber()) + ",";
   j += "\"ea_name\":\""         + EJ(EAName) + "\",";
   j += "\"broker\":\""          + EJ(AccountCompany()) + "\",";
   j += "\"platform\":\"MT4\",";
   j += "\"category\":\""        + Category + "\",";
   j += "\"initial_balance\":0,";
   j += "\"current_balance\":"   + DoubleToString(AccountBalance(), 2) + ",";
   j += "\"current_equity\":"    + DoubleToString(AccountEquity(), 2) + ",";
   j += "\"total_deposits\":"    + DoubleToString(gDeposits, 2) + ",";
   j += "\"total_withdrawals\":" + DoubleToString(gWithdraw, 2) + ",";
   j += "\"currency\":\"" + AccountCurrency() + "\",";
   j += "\"leverage\":"          + IntegerToString(AccountLeverage()) + ",";

   // Closed trades
   j += "\"trades\":[";
   int n = OrdersHistoryTotal(), cnt = 0;
   for(int i = 0; i < n; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < from) continue;
      if(IsBalanceOp(i)) continue;
      if(OrderType() > 1) continue;  // skip pending/cancelled

      if(cnt > 0) j += ",";
      j += "{\"trade_id\":"    + IntegerToString(OrderTicket())
         + ",\"symbol\":\""    + EJ(OrderSymbol()) + "\""
         + ",\"type\":\""      + (OrderType() == 0 ? "BUY" : "SELL") + "\""
         + ",\"lots\":"        + DoubleToString(OrderLots(), 2)
         + ",\"open_price\":"  + DoubleToString(OrderOpenPrice(), 5)
         + ",\"close_price\":" + DoubleToString(OrderClosePrice(), 5)
         + ",\"open_time\":\"" + TimeToStr(OrderOpenTime(), TIME_DATE|TIME_MINUTES) + "\""
         + ",\"close_time\":\""+ TimeToStr(OrderCloseTime(), TIME_DATE|TIME_MINUTES)+ "\""
         + ",\"profit\":"      + DoubleToString(OrderProfit()+OrderSwap()+OrderCommission(), 2)
         + ",\"swap\":"        + DoubleToString(OrderSwap(), 2)
         + ",\"commission\":"  + DoubleToString(OrderCommission(), 2)
         + "}";
      cnt++;
   }
   j += "],";

   // Open trades
   j += "\"open_trades\":[";
   int m = OrdersTotal(), oc = 0;
   for(int i = 0; i < m; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() > 1) continue;

      if(oc > 0) j += ",";
      j += "{\"trade_id\":"     + IntegerToString(OrderTicket())
         + ",\"symbol\":\""     + EJ(OrderSymbol()) + "\""
         + ",\"type\":\""       + (OrderType() == 0 ? "BUY" : "SELL") + "\""
         + ",\"lots\":"         + DoubleToString(OrderLots(), 2)
         + ",\"open_price\":"   + DoubleToString(OrderOpenPrice(), 5)
         + ",\"current_price\":"+ DoubleToString(OrderClosePrice(), 5)
         + ",\"open_time\":\"" + TimeToStr(OrderOpenTime(), TIME_DATE|TIME_MINUTES) + "\""
         + ",\"profit\":"       + DoubleToString(OrderProfit()+OrderSwap()+OrderCommission(), 2)
         + "}";
      oc++;
   }
   j += "]}";

   string hdr = "Content-Type: application/json\r\n";
   char post[], res[]; string rHdr;
   ArrayResize(post, StringToCharArray(j, post, 0, WHOLE_ARRAY) - 1);
   int rc = WebRequest("POST", WebhookURL, hdr, 5000, post, res, rHdr);

   if(rc == 200) Print("✓ Sent: ", cnt, " trades, ", oc, " open");
   else if(rc == -1) Print("✗ Add URL to allowed list in MT4!");
   else Print("✗ HTTP ", rc);
}
