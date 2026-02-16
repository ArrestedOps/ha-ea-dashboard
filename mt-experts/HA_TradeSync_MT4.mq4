//+------------------------------------------------------------------+
//|                                           HA_TradeSync_MT4.mq4   |
//|                                   Home Assistant Trade Sync EA   |
//|                         Sends trades to HA EA Dashboard via HTTP |
//+------------------------------------------------------------------+
#property copyright "EA Trading Dashboard"
#property link      "https://github.com/ArrestedOps/ha-ea-dashboard"
#property version   "2.00"
#property strict

//--- Input Parameters
input string WebhookURL = "http://192.168.1.100:8099/api/webhook/trade";  // Home Assistant URL
input string SecretKey = "";                    // Webhook Secret (optional)
input string EAName = "My EA";                  // EA Name in Dashboard
input string Category = "live";                 // Category: live, demo, copy, challenge
input bool SendHistoryOnStart = true;           // Send trade history on start
input int HistoryDays = 90;                     // Days of history to send

//--- Global Variables
datetime lastCheck = 0;
int checkInterval = 5;  // Check every 5 seconds

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===========================================");
   Print("HA Trade Sync EA v2.0 Initialized");
   Print("EA Name: ", EAName);
   Print("Category: ", Category);
   Print("Webhook URL: ", WebhookURL);
   Print("===========================================");
   
   if(SendHistoryOnStart)
   {
      Print("Sending trade history...");
      SendTradeHistory();
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("HA Trade Sync EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for closed trades every N seconds
   if(TimeCurrent() - lastCheck >= checkInterval)
   {
      CheckClosedTrades();
      lastCheck = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Check for newly closed trades                                      |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   static int lastTotal = 0;
   int currentTotal = OrdersHistoryTotal();
   
   if(currentTotal > lastTotal)
   {
      // New trade(s) closed - send the latest one(s)
      for(int i = lastTotal; i < currentTotal; i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         {
            if(OrderType() <= OP_SELL)  // Only BUY/SELL trades
            {
               SendTrade(i);
            }
         }
      }
      lastTotal = currentTotal;
   }
}

//+------------------------------------------------------------------+
//| Send trade history on start                                        |
//+------------------------------------------------------------------+
void SendTradeHistory()
{
   datetime startDate = TimeCurrent() - (HistoryDays * 24 * 3600);
   int sent = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderType() <= OP_SELL && OrderCloseTime() >= startDate)
         {
            if(SendTrade(i))
               sent++;
         }
      }
   }
   
   Print("Sent ", sent, " historical trades to dashboard");
}

//+------------------------------------------------------------------+
//| Send single trade to webhook                                       |
//+------------------------------------------------------------------+
bool SendTrade(int orderIndex)
{
   if(!OrderSelect(orderIndex, SELECT_BY_POS, MODE_HISTORY))
      return false;
   
   // Build JSON payload
   string json = "{";
   json += "\"secret\": \"" + SecretKey + "\",";
   json += "\"account_number\": " + IntegerToString(AccountNumber()) + ",";
   json += "\"ea_name\": \"" + EAName + "\",";
   json += "\"category\": \"" + Category + "\",";
   json += "\"platform\": \"MT4\",";
   json += "\"broker\": \"" + AccountCompany() + "\",";
   json += "\"trade\": {";
   json += "\"trade_id\": \"" + IntegerToString(OrderTicket()) + "\",";
   json += "\"open_time\": \"" + TimeToString(OrderOpenTime(), TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"close_time\": \"" + TimeToString(OrderCloseTime(), TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"symbol\": \"" + OrderSymbol() + "\",";
   json += "\"type\": \"" + (OrderType() == OP_BUY ? "BUY" : "SELL") + "\",";
   json += "\"lots\": " + DoubleToString(OrderLots(), 2) + ",";
   json += "\"open_price\": " + DoubleToString(OrderOpenPrice(), 5) + ",";
   json += "\"close_price\": " + DoubleToString(OrderClosePrice(), 5) + ",";
   json += "\"profit\": " + DoubleToString(OrderProfit(), 2) + ",";
   json += "\"commission\": " + DoubleToString(OrderCommission(), 2) + ",";
   json += "\"swap\": " + DoubleToString(OrderSwap(), 2) + ",";
   json += "\"balance\": " + DoubleToString(AccountBalance(), 2) + ",";
   json += "\"comment\": \"" + OrderComment() + "\"";
   json += "}}";
   
   // Send HTTP POST
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   
   int timeout = 5000;
   int res = WebRequest(
      "POST",
      WebhookURL,
      headers,
      timeout,
      StringToCharArray(json, post),
      result,
      headers
   );
   
   if(res == 200)
   {
      Print("✓ Trade #", OrderTicket(), " sent successfully");
      return true;
   }
   else
   {
      Print("✗ Failed to send trade #", OrderTicket(), ". Error: ", res);
      return false;
   }
}
//+------------------------------------------------------------------+
