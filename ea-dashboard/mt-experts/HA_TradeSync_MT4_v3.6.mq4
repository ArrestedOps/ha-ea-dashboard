//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v3.6.mq4 |
//|                    FIXED: Proper filtering of deposits/trades!   |
//+------------------------------------------------------------------+
#property version   "3.60"
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
   Print("=== EA Dashboard v3.6 - PROPER FILTERING ===");
   AnalyzeAccountHistory();
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

bool IsBalanceOperation(int orderIndex)
{
   // Check if order is a balance operation (deposit/withdrawal)
   if(!OrderSelect(orderIndex, SELECT_BY_POS, MODE_HISTORY))
      return false;
   
   string comment = OrderComment();
   StringToLower(comment);
   
   // Check for balance operation keywords
   if(StringFind(comment, "balance") >= 0) return true;
   if(StringFind(comment, "deposit") >= 0) return true;
   if(StringFind(comment, "withdrawal") >= 0) return true;
   if(StringFind(comment, "withdraw") >= 0) return true;
   if(StringFind(comment, "credit") >= 0) return true;
   
   // Check if profit is exactly equal to balance change (no swap/commission)
   // Balance operations usually have 0 swap and 0 commission
   if(OrderSwap() == 0 && OrderCommission() == 0 && OrderProfit() > 0)
   {
      // Might be a deposit - check if it's a very round number
      double profit = OrderProfit();
      if(MathMod(profit, 100) == 0 || MathMod(profit, 1000) == 0)
      {
         return true; // Likely a deposit
      }
   }
   
   return false;
}

void AnalyzeAccountHistory()
{
   Print("Analyzing account history (filtering deposits)...");
   
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   int totalOrders = OrdersHistoryTotal();
   
   double tradesProfitSum = 0;
   totalDeposits = 0;
   totalWithdrawals = 0;
   
   for(int i = 0; i < totalOrders; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate && OrderType() <= 1) // Only BUY/SELL
         {
            if(IsBalanceOperation(i))
            {
               // This is a balance operation
               double amount = OrderProfit();
               if(amount > 0)
               {
                  totalDeposits += amount;
                  Print("DEPOSIT detected: $", DoubleToString(amount, 2), " - ", OrderComment());
               }
               else if(amount < 0)
               {
                  totalWithdrawals += MathAbs(amount);
                  Print("WITHDRAWAL detected: $", DoubleToString(MathAbs(amount), 2), " - ", OrderComment());
               }
            }
            else
            {
               // This is a real trade
               tradesProfitSum += OrderProfit() + OrderSwap() + OrderCommission();
            }
         }
      }
   }
   
   // Calculate initial balance
   initialBalance = AccountBalance() - tradesProfitSum - totalDeposits + totalWithdrawals;
   
   if(initialBalance < 100)
   {
      initialBalance = 1000;
      Print("WARNING: Could not calculate initial balance, using fallback");
   }
   
   Print("=== ACCOUNT ANALYSIS ===");
   Print("Initial Balance: $", DoubleToString(initialBalance, 2));
   Print("Total Deposits: $", DoubleToString(totalDeposits, 2));
   Print("Total Withdrawals: $", DoubleToString(totalWithdrawals, 2));
   Print("Trades Profit: $", DoubleToString(tradesProfitSum, 2));
   Print("Current Balance: $", DoubleToString(AccountBalance(), 2));
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
   
   // Closed trades (ONLY real trades, NO balance operations)
   json += "\"trades\":[";
   int totalTrades = OrdersHistoryTotal();
   int count = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderType() <= 1 && OrderCloseTime() >= startDate)
         {
            // Skip balance operations
            if(IsBalanceOperation(i))
               continue;
            
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
         if(OrderType() <= 1)
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
   
   // Send
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
   int res = WebRequest("POST", WebhookURL, headers, 5000, post, result, result_headers);
   
   if(res == 200)
      Print("✓ Batch OK (", count, " real trades sent)");
   else if(res == -1)
      Print("✗ WebRequest ERROR! Add URL!");
   else
      Print("✗ Server error: ", res);
}

string GetOrderTypeStr()
{
   if(OrderType() == OP_BUY) return "BUY";
   if(OrderType() == OP_SELL) return "SELL";
   return "PENDING";
}
