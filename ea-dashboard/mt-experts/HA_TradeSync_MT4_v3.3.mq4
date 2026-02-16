//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v3.3.mq4 |
//|                            EA Trading Dashboard - BATCH VERSION |
//|                  Sends ALL trades in ONE webhook for efficiency |
//+------------------------------------------------------------------+
#property copyright "EA Trading Dashboard v3.3"
#property version   "3.30"
#property strict

input string WebhookURL = "http://api.dobko.it/api/webhook/batch";
input string SecretKey = "your_secret_key";
input string EAName = "My EA";
input string Category = "live";
input bool SendHistoryOnStart = true;
input int HistoryDays = 90;
input int LiveTradesIntervalSec = 10;

datetime lastCheck = 0;
double initialBalance = 0;
bool initialized = false;

int OnInit()
{
   Print("=== EA Dashboard Sync v3.3 BATCH MODE ===");
   
   // Calculate initial balance from account equity minus profits
   CalculateInitialBalance();
   
   // Send everything in one batch
   if(SendHistoryOnStart)
   {
      SendBatchData();
   }
   
   initialized = true;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { }

void OnTick()
{
   if(TimeCurrent() - lastCheck >= LiveTradesIntervalSec)
   {
      SendBatchData();
      lastCheck = TimeCurrent();
   }
}

void CalculateInitialBalance()
{
   // Get first trade to estimate initial balance
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   int totalTrades = OrdersHistoryTotal();
   
   double totalProfit = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate)
         {
            totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   // Initial balance = current balance - all profits
   initialBalance = AccountBalance() - totalProfit;
   
   if(initialBalance < 100)
   {
      // Fallback: use account equity
      initialBalance = AccountEquity() - totalProfit;
      if(initialBalance < 100) initialBalance = 1000;
   }
   
   Print("Calculated Initial Balance: $", DoubleToString(initialBalance, 2));
   Print("Current Balance: $", DoubleToString(AccountBalance(), 2));
   Print("Total Profit from Trades: $", DoubleToString(totalProfit, 2));
}

void SendBatchData()
{
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   
   // Build JSON
   string json = "{";
   json += "\"secret\":\"" + SecretKey + "\",";
   json += "\"account_number\":" + IntegerToString(AccountNumber()) + ",";
   json += "\"ea_name\":\"" + EAName + "\",";
   json += "\"broker\":\"" + AccountCompany() + "\",";
   json += "\"platform\":\"MT4\",";
   json += "\"category\":\"" + Category + "\",";
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"current_balance\":" + DoubleToString(AccountBalance(), 2) + ",";
   json += "\"current_equity\":" + DoubleToString(AccountEquity(), 2) + ",";
   json += "\"currency\":\"USD\",";
   
   // Closed trades
   json += "\"trades\":[";
   int totalTrades = OrdersHistoryTotal();
   int count = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate)
         {
            if(count > 0) json += ",";
            
            json += "{";
            json += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
            json += "\"symbol\":\"" + OrderSymbol() + "\",";
            json += "\"type\":\"" + GetOrderTypeStr() + "\",";
            json += "\"lots\":" + DoubleToString(OrderLots(), 2) + ",";
            json += "\"open_price\":" + DoubleToString(OrderOpenPrice(), 5) + ",";
            json += "\"close_price\":" + DoubleToString(OrderClosePrice(), 5) + ",";
            json += "\"open_time\":\"" + TimeToStr(OrderOpenTime(), TIME_DATE|TIME_MINUTES) + "\",";
            json += "\"close_time\":\"" + TimeToStr(OrderCloseTime(), TIME_DATE|TIME_MINUTES) + "\",";
            json += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2) + ",";
            json += "\"commission\":" + DoubleToString(OrderCommission(), 2) + ",";
            json += "\"swap\":" + DoubleToString(OrderSwap(), 2);
            json += "}";
            
            count++;
         }
      }
   }
   json += "],";
   
   // Open trades
   json += "\"open_trades\":[";
   int totalOpen = OrdersTotal();
   count = 0;
   
   for(int i = 0; i < totalOpen; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(count > 0) json += ",";
         
         json += "{";
         json += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
         json += "\"symbol\":\"" + OrderSymbol() + "\",";
         json += "\"type\":\"" + GetOrderTypeStr() + "\",";
         json += "\"lots\":" + DoubleToString(OrderLots(), 2) + ",";
         json += "\"open_price\":" + DoubleToString(OrderOpenPrice(), 5) + ",";
         json += "\"current_price\":" + DoubleToString(OrderClosePrice(), 5) + ",";
         json += "\"open_time\":\"" + TimeToStr(OrderOpenTime(), TIME_DATE|TIME_MINUTES) + "\",";
         json += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2) + ",";
         json += "\"commission\":" + DoubleToString(OrderCommission(), 2) + ",";
         json += "\"swap\":" + DoubleToString(OrderSwap(), 2);
         json += "}";
         
         count++;
      }
   }
   json += "]";
   json += "}";
   
   // Send
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
   
   int res = WebRequest("POST", WebhookURL, headers, 5000, post, result, result_headers);
   
   if(res == 200)
   {
      Print("✓ Batch sent successfully (", totalTrades, " trades, ", totalOpen, " open)");
   }
   else if(res == -1)
   {
      Print("✗ WebRequest ERROR! Code: ", GetLastError());
      Print("  Add URL to allowed list: Tools → Options → Expert Advisors");
   }
   else
   {
      Print("✗ Server responded with code: ", res);
   }
}

string GetOrderTypeStr()
{
   switch(OrderType())
   {
      case OP_BUY: return "BUY";
      case OP_SELL: return "SELL";
      case OP_BUYLIMIT: return "BUY LIMIT";
      case OP_SELLLIMIT: return "SELL LIMIT";
      case OP_BUYSTOP: return "BUY STOP";
      case OP_SELLSTOP: return "SELL STOP";
      default: return "UNKNOWN";
   }
}
