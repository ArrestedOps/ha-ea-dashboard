//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v3.2.mq4 |
//|                                   EA Trading Dashboard Sync v3.2 |
//|                        Sends trades + live positions + deposits  |
//+------------------------------------------------------------------+
#property copyright "EA Trading Dashboard v3.2"
#property link      "https://github.com/ArrestedOps/ha-ea-dashboard"
#property version   "3.20"
#property strict

// --- Input Parameters ---
input string WebhookURL = "http://api.dobko.it/api/webhook/trade";  // Webhook URL
input string SecretKey = "your_secret_key_here";                     // Security Key
input string EAName = "My EA";                                       // EA Name for Dashboard
input string Category = "live";                                       // Category: live, demo, copy
input bool SendHistory = true;                                       // Send Trade History on Start
input int HistoryDays = 90;                                          // History Days to Send
input int CheckIntervalSeconds = 10;                                 // Check Interval for Live Trades

// --- Global Variables ---
datetime lastCheck = 0;
double initialBalance = 0;
double totalWithdrawals = 0;
double totalDeposits = 0;
bool initialized = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== EA Trading Dashboard Sync v3.2 Starting ===");
   Print("Webhook URL: ", WebhookURL);
   Print("EA Name: ", EAName);
   Print("Category: ", Category);
   
   // Get initial balance from first trade or current
   if(SendHistory && HistoryDays > 0)
   {
      CalculateInitialBalance();
      SendTradeHistory();
   }
   else
   {
      initialBalance = AccountBalance();
   }
   
   // Send current live trades
   SendLiveTrades();
   
   initialized = true;
   Print("=== Initialization Complete ===");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA Trading Dashboard Sync stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for live trades periodically
   if(TimeCurrent() - lastCheck >= CheckIntervalSeconds)
   {
      SendLiveTrades();
      lastCheck = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Calculate initial balance from history                             |
//+------------------------------------------------------------------+
void CalculateInitialBalance()
{
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   int totalTrades = OrdersHistoryTotal();
   
   if(totalTrades == 0)
   {
      initialBalance = AccountBalance();
      return;
   }
   
   // Find oldest trade
   double oldestBalance = AccountBalance();
   datetime oldestTime = TimeCurrent();
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() < oldestTime && OrderCloseTime() >= startDate)
         {
            oldestTime = OrderCloseTime();
            // Estimate balance before this trade
            oldestBalance = OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   // Calculate initial from first trade
   initialBalance = AccountBalance();
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate)
         {
            initialBalance -= (OrderProfit() + OrderSwap() + OrderCommission());
         }
      }
   }
   
   if(initialBalance < 100) initialBalance = 1000; // Fallback
   
   Print("Calculated Initial Balance: ", initialBalance);
}

//+------------------------------------------------------------------+
//| Send trade history                                                 |
//+------------------------------------------------------------------+
void SendTradeHistory()
{
   Print("Sending trade history...");
   
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   int totalTrades = OrdersHistoryTotal();
   int sentCount = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate)
         {
            SendTrade(OrderTicket(), false);
            sentCount++;
            Sleep(50); // Prevent flooding
         }
      }
   }
   
   Print("Sent ", sentCount, " historical trades");
}

//+------------------------------------------------------------------+
//| Send live/open trades                                              |
//+------------------------------------------------------------------+
void SendLiveTrades()
{
   int totalOpen = OrdersTotal();
   
   if(totalOpen == 0) return;
   
   for(int i = 0; i < totalOpen; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         SendTrade(OrderTicket(), true);
      }
   }
}

//+------------------------------------------------------------------+
//| Send single trade to webhook                                       |
//+------------------------------------------------------------------+
void SendTrade(int ticket, bool isLive)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      Print("Failed to select order: ", ticket);
      return;
   }
   
   // Build JSON payload
   string json = "{";
   json += "\"secret\":\"" + SecretKey + "\",";
   json += "\"account_number\":" + IntegerToString(AccountNumber()) + ",";
   json += "\"ea_name\":\"" + EAName + "\",";
   json += "\"broker\":\"" + AccountCompany() + "\",";
   json += "\"platform\":\"MT4\",";
   json += "\"category\":\"" + Category + "\",";
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"withdrawals\":" + DoubleToString(totalWithdrawals, 2) + ",";
   json += "\"deposits\":" + DoubleToString(totalDeposits, 2) + ",";
   
   if(isLive)
   {
      json += "\"open_trade\":{";
      json += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
      json += "\"symbol\":\"" + OrderSymbol() + "\",";
      json += "\"type\":\"" + GetOrderType() + "\",";
      json += "\"lots\":" + DoubleToString(OrderLots(), 2) + ",";
      json += "\"open_price\":" + DoubleToString(OrderOpenPrice(), 5) + ",";
      json += "\"open_time\":\"" + TimeToString(OrderOpenTime(), TIME_DATE|TIME_MINUTES) + "\",";
      json += "\"current_price\":" + DoubleToString(OrderClosePrice(), 5) + ",";
      json += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2) + ",";
      json += "\"balance\":" + DoubleToString(AccountBalance(), 2);
      json += "}";
   }
   else
   {
      json += "\"trade\":{";
      json += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
      json += "\"symbol\":\"" + OrderSymbol() + "\",";
      json += "\"type\":\"" + GetOrderType() + "\",";
      json += "\"lots\":" + DoubleToString(OrderLots(), 2) + ",";
      json += "\"open_price\":" + DoubleToString(OrderOpenPrice(), 5) + ",";
      json += "\"close_price\":" + DoubleToString(OrderClosePrice(), 5) + ",";
      json += "\"open_time\":\"" + TimeToString(OrderOpenTime(), TIME_DATE|TIME_MINUTES) + "\",";
      json += "\"close_time\":\"" + TimeToString(OrderCloseTime(), TIME_DATE|TIME_MINUTES) + "\",";
      json += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2) + ",";
      json += "\"balance\":" + DoubleToString(AccountBalance(), 2);
      json += "}";
   }
   
   json += "}";
   
   // Send via WebRequest
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
   
   int res = WebRequest("POST", WebhookURL, headers, 5000, post, result, result_headers);
   
   if(res == 200)
   {
      if(!isLive) Print("✓ Trade sent: ", ticket);
   }
   else if(res == -1)
   {
      int error = GetLastError();
      Print("✗ WebRequest failed! Error: ", error);
      Print("  Make sure URL is allowed in Tools → Options → Expert Advisors");
   }
   else
   {
      Print("✗ Server error: ", res);
   }
}

//+------------------------------------------------------------------+
//| Get order type as string                                           |
//+------------------------------------------------------------------+
string GetOrderType()
{
   if(OrderType() == OP_BUY) return "BUY";
   if(OrderType() == OP_SELL) return "SELL";
   if(OrderType() == OP_BUYLIMIT) return "BUY LIMIT";
   if(OrderType() == OP_SELLLIMIT) return "SELL LIMIT";
   if(OrderType() == OP_BUYSTOP) return "BUY STOP";
   if(OrderType() == OP_SELLSTOP) return "SELL STOP";
   return "UNKNOWN";
}
//+------------------------------------------------------------------+
