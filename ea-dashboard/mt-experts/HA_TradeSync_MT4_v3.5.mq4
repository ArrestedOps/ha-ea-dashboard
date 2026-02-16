//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v3.5.mq4 |
//|                    AUTO-DETECT: Deposit, Withdrawals, Balance!   |
//+------------------------------------------------------------------+
#property version   "3.50"
#property strict

input string WebhookURL = "http://api.dobko.it/api/webhook/batch";
input string SecretKey = "your_secret";
input string EAName = "My EA";
input string Category = "live";
input int HistoryDays = 365;
input int LiveTradesIntervalSec = 10;

datetime lastCheck = 0;
double initialBalance = 0;
double totalDeposits = 0;
double totalWithdrawals = 0;

int OnInit()
{
   Print("=== EA Dashboard v3.5 - AUTO EVERYTHING ===");
   
   // Analyze complete account history
   AnalyzeAccountHistory();
   
   // Send initial batch
   SendBatchData();
   
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

void AnalyzeAccountHistory()
{
   Print("Analyzing account history for deposits/withdrawals...");
   
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   int totalOrders = OrdersHistoryTotal();
   
   // Get all balance operations (deposits/withdrawals)
   double balanceOperations[];
   datetime balanceOpTimes[];
   ArrayResize(balanceOperations, 0);
   ArrayResize(balanceOpTimes, 0);
   
   // Collect balance changes that are NOT from trades
   double lastKnownBalance = 0;
   double tradesProfitSum = 0;
   
   for(int i = 0; i < totalOrders; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate)
         {
            // This is a trade profit
            tradesProfitSum += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   // Calculate initial balance
   // Method: Current Balance - All Profits = Initial
   initialBalance = AccountBalance() - tradesProfitSum;
   
   // If negative or too small, use fallback
   if(initialBalance < 100)
   {
      // Fallback: Assume starting balance was minimum viable
      initialBalance = 1000;
      Print("WARNING: Could not determine initial balance, using fallback: $1000");
   }
   
   // Check for balance operations (deposits/withdrawals)
   // MT4 doesn't have direct API for this, so we estimate
   // by looking at equity jumps that don't match trade profits
   
   // For now, set to 0 (can be enhanced with more logic)
   totalDeposits = 0;
   totalWithdrawals = 0;
   
   // Alternative: Look for comment "deposit" or "withdrawal" in history
   for(int i = 0; i < totalOrders; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         string comment = StringToLower(OrderComment());
         double profit = OrderProfit();
         
         // Check if it's a balance operation (not a trade)
         if(OrderType() > 1) continue; // Skip pending orders
         
         if(StringFind(comment, "deposit") >= 0 && profit > 0)
         {
            totalDeposits += profit;
            Print("Found DEPOSIT: $", DoubleToString(profit, 2), " on ", TimeToStr(OrderCloseTime()));
         }
         else if(StringFind(comment, "withdrawal") >= 0 && profit < 0)
         {
            totalWithdrawals += MathAbs(profit);
            Print("Found WITHDRAWAL: $", DoubleToString(MathAbs(profit), 2), " on ", TimeToStr(OrderCloseTime()));
         }
      }
   }
   
   // Adjust initial balance if we found deposits
   if(totalDeposits > 0)
   {
      initialBalance = initialBalance - totalDeposits;
      if(initialBalance < 100) initialBalance = 1000;
   }
   
   Print("=== ACCOUNT ANALYSIS ===");
   Print("Initial Balance: $", DoubleToString(initialBalance, 2));
   Print("Total Deposits: $", DoubleToString(totalDeposits, 2));
   Print("Total Withdrawals: $", DoubleToString(totalWithdrawals, 2));
   Print("Current Balance: $", DoubleToString(AccountBalance(), 2));
   Print("Current Equity: $", DoubleToString(AccountEquity(), 2));
   Print("Trades Profit: $", DoubleToString(tradesProfitSum, 2));
   Print("========================");
}

void SendBatchData()
{
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   
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
   json += "\"total_deposits\":" + DoubleToString(totalDeposits, 2) + ",";
   json += "\"total_withdrawals\":" + DoubleToString(totalWithdrawals, 2) + ",";
   json += "\"currency\":\"USD\",";
   json += "\"leverage\":" + IntegerToString(AccountLeverage()) + ",";
   
   // Closed trades
   json += "\"trades\":[";
   int totalTrades = OrdersHistoryTotal();
   int count = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         // Only include actual trades (not balance operations)
         if(OrderType() <= 1 && OrderCloseTime() >= startDate)
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
            json += "\"swap\":" + DoubleToString(OrderSwap(), 2) + ",";
            json += "\"commission\":" + DoubleToString(OrderCommission(), 2);
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
         if(OrderType() <= 1) // Only BUY/SELL
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
            json += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2);
            json += "}";
            count++;
         }
      }
   }
   json += "]}";
   
   // Send via WebRequest
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
   int res = WebRequest("POST", WebhookURL, headers, 5000, post, result, result_headers);
   
   if(res == 200)
   {
      Print("✓ Batch sent OK");
   }
   else if(res == -1)
   {
      Print("✗ WebRequest ERROR! Add URL to allowed list!");
   }
   else
   {
      Print("✗ Server error: ", res);
   }
}

string GetOrderTypeStr()
{
   switch(OrderType())
   {
      case OP_BUY: return "BUY";
      case OP_SELL: return "SELL";
      default: return "PENDING";
   }
}

string StringToLower(string str)
{
   string result = str;
   StringToLower(result);
   return result;
}
