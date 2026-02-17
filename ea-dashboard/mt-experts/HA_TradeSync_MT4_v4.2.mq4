//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v4.2.mq4 |
//| FINAL: Covers ALL broker deposit formats incl Black Bull         |
//+------------------------------------------------------------------+
#property version   "4.20"
#property strict

input string WebhookURL    = "http://api.dobko.it/api/webhook/batch";
input string SecretKey     = "your_secret";
input string EAName        = "My EA";
input string Category      = "live";    // live / copy / demo
input int    HistoryDays   = 365;
input int    UpdateSec     = 10;

datetime lastSent  = 0;
double   gInitial  = 0;
double   gDeposits = 0;
double   gWithdraw = 0;

int OnInit()
{
   Print("=== HA TradeSync v4.2 starting... ===");
   ScanHistory();
   SendData();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){}
void OnTick()
{
   if(TimeCurrent() - lastSent >= UpdateSec){ SendData(); lastSent = TimeCurrent(); }
}

// ---------------------------------------------------------------
// DEPOSIT DETECTION - covers every known broker format
// ---------------------------------------------------------------
bool IsDeposit(int idx, bool histMode)
{
   // --- select order ---
   if(histMode){  if(!OrderSelect(idx, SELECT_BY_POS, MODE_HISTORY)) return false; }
   else         {  if(!OrderSelect(idx, SELECT_BY_POS, MODE_TRADES))  return false; }

   // 1) OrderType 6 = Balance, 7 = Credit  (LiteFinance, most MT4 brokers)
   int ot = OrderType();
   if(ot == 6 || ot == 7) return true;

   // 2) Comment analysis – catches Black Bull "balance" rows
   //    MT4 statement shows type="balance" but API returns ot=BUY(0)
   //    The magic: comment contains NO symbol-like text AND profit is round
   string cmt = OrderComment();
   string cLow = cmt;
   StringToLower(cLow);

   // Explicit keywords
   if(StringFind(cLow,"balance")    >= 0) return true;
   if(StringFind(cLow,"deposit")    >= 0) return true;
   if(StringFind(cLow,"withdrawal") >= 0) return true;
   if(StringFind(cLow,"transfer")   >= 0) return true;  // Black Bull: "Transfer_from_XXXXXXX_Wallet"
   if(StringFind(cLow,"wallet")     >= 0) return true;  // same
   if(StringFind(cLow,"dpst")       >= 0) return true;  // LiteFinance alt format
   if(StringFind(cLow,"vps")        >= 0) return true;  // VPS-PAYMENT (withdrawal)
   if(StringFind(cLow,"credit")     >= 0) return true;

   // 3) Heuristic: no symbol, no swap, no commission, profit is large round number
   if(OrderSymbol() == "")
   {
      double p = OrderProfit();
      if(p == MathRound(p) && MathAbs(p) >= 500) return true;
   }

   return false;
}

// ---------------------------------------------------------------
void ScanHistory()
{
   gDeposits = 0; gWithdraw = 0;
   double tradeProfit = 0;
   datetime from = TimeCurrent() - HistoryDays * 86400;
   int n = OrdersHistoryTotal();

   for(int i = 0; i < n; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < from) continue;

      if(IsDeposit(i, true))
      {
         double amt = OrderProfit();
         if(amt > 0) gDeposits += amt;
         else        gWithdraw += MathAbs(amt);
         Print("Balance op: ", OrderComment(), " = ", amt);
      }
      else if(OrderType() <= 1)
      {
         tradeProfit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   gInitial = (gDeposits > 0) ? 0 :
              MathMax(AccountBalance() - tradeProfit, 0);

   Print("Deposits=$",DoubleToString(gDeposits,2),
         " Withdrawals=$",DoubleToString(gWithdraw,2),
         " Initial=$",DoubleToString(gInitial,2),
         " TradeProfit=$",DoubleToString(tradeProfit,2));
}

// ---------------------------------------------------------------
string EscJson(string s){ StringReplace(s,"\"","'"); return s; }

void SendData()
{
   datetime from = TimeCurrent() - HistoryDays * 86400;
   string j = "{";
   j += "\"secret\":\""          + SecretKey + "\",";
   j += "\"account_number\":"    + IntegerToString(AccountNumber()) + ",";
   j += "\"ea_name\":\""         + EscJson(EAName) + "\",";
   j += "\"broker\":\""          + EscJson(AccountCompany()) + "\",";
   j += "\"platform\":\"MT4\",";
   j += "\"category\":\""        + Category + "\",";
   j += "\"initial_balance\":"   + DoubleToString(gInitial,2) + ",";
   j += "\"current_balance\":"   + DoubleToString(AccountBalance(),2) + ",";
   j += "\"current_equity\":"    + DoubleToString(AccountEquity(),2) + ",";
   j += "\"total_deposits\":"    + DoubleToString(gDeposits,2) + ",";
   j += "\"total_withdrawals\":" + DoubleToString(gWithdraw,2) + ",";
   j += "\"currency\":\"USD\",";
   j += "\"leverage\":"          + IntegerToString(AccountLeverage()) + ",";

   // --- closed trades ---
   j += "\"trades\":[";
   int n = OrdersHistoryTotal(), cnt = 0;
   for(int i = 0; i < n; i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderCloseTime() < from) continue;
      if(IsDeposit(i,true)) continue;
      if(OrderType() > 1) continue;

      if(cnt) j += ",";
      j += "{\"trade_id\":"   + IntegerToString(OrderTicket())
         + ",\"symbol\":\""   + EscJson(OrderSymbol()) + "\""
         + ",\"type\":\""     + (OrderType()==0?"BUY":"SELL") + "\""
         + ",\"lots\":"       + DoubleToString(OrderLots(),2)
         + ",\"open_price\":" + DoubleToString(OrderOpenPrice(),5)
         + ",\"close_price\":"+ DoubleToString(OrderClosePrice(),5)
         + ",\"open_time\":\"" + TimeToStr(OrderOpenTime(),TIME_DATE|TIME_MINUTES) + "\""
         + ",\"close_time\":\""+ TimeToStr(OrderCloseTime(),TIME_DATE|TIME_MINUTES)+ "\""
         + ",\"profit\":"     + DoubleToString(OrderProfit()+OrderSwap()+OrderCommission(),2)
         + ",\"swap\":"       + DoubleToString(OrderSwap(),2)
         + ",\"commission\":"  + DoubleToString(OrderCommission(),2)
         + "}";
      cnt++;
   }
   j += "],";

   // --- open trades ---
   j += "\"open_trades\":[";
   int m = OrdersTotal(), oc = 0;
   for(int i = 0; i < m; i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderType() > 1) continue;
      if(oc) j += ",";
      j += "{\"trade_id\":"    + IntegerToString(OrderTicket())
         + ",\"symbol\":\""    + EscJson(OrderSymbol()) + "\""
         + ",\"type\":\""      + (OrderType()==0?"BUY":"SELL") + "\""
         + ",\"lots\":"        + DoubleToString(OrderLots(),2)
         + ",\"open_price\":"  + DoubleToString(OrderOpenPrice(),5)
         + ",\"current_price\":"+ DoubleToString(OrderClosePrice(),5)
         + ",\"open_time\":\"" + TimeToStr(OrderOpenTime(),TIME_DATE|TIME_MINUTES) + "\""
         + ",\"profit\":"      + DoubleToString(OrderProfit()+OrderSwap()+OrderCommission(),2)
         + "}";
      oc++;
   }
   j += "]}";

   string hdr="Content-Type: application/json\r\n";
   char post[],res[]; string rHdr;
   ArrayResize(post, StringToCharArray(j,post,0,WHOLE_ARRAY)-1);
   int rc = WebRequest("POST",WebhookURL,hdr,5000,post,res,rHdr);
   if(rc==200) Print("✓ Sent: ",cnt," trades, ",oc," open");
   else if(rc==-1) Print("✗ WebRequest error – add URL to allowed list");
   else Print("✗ HTTP ",rc);
}
