//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v3.7.mq4 |
//|                  FINAL FIX: Proper balance operation detection   |
//+------------------------------------------------------------------+
#property version   "3.70"
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
   Print("=== EA Dashboard v3.7 - FINAL BALANCE DETECTION ===");
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
   if(!OrderSelect(orderIndex, SELECT_BY_POS, MODE_HISTORY))
      return false;
   
   // Method 1: Check OrderType
   // MT4 balance operations have special types:
   // OP_BALANCE = 6, OP_CREDIT = 7
   int orderType = OrderType();
   if(orderType == 6 || orderType == 7) // Balance or Credit
   {
      Print("Balance operation detected by TYPE: ", orderType, " Ticket: ", OrderTicket());
      return true;
   }
   
   // Method 2: Check comment for balance keywords
   string comment = OrderComment();
   StringToLower(comment);
   
   if(StringFind(comment, "balance") >= 0) return true;
   if(StringFind(comment, "deposit") >= 0) return true;
   if(StringFind(comment, "withdrawal") >= 0) return true;
   if(StringFind(comment, "withdraw") >= 0) return true;
   if(StringFind(comment, "credit") >= 0) return true;
   if(StringFind(comment, "transfer") >= 0) return true;
   if(StringFind(comment, "wallet") >= 0) return true;
   if(StringFind(comment, "bonus") >= 0) return true;
   
   // Method 3: Check if it's a trade with no market symbol
   string symbol = OrderSymbol();
   if(symbol == "" || StringLen(symbol) == 0)
   {
      return true; // No symbol = balance operation
   }
   
   // Method 4: Check characteristics
   // Balance ops usually have: no swap, no commission, round profit
   if(OrderSwap() == 0 && OrderCommission() == 0)
   {
      double profit = OrderProfit();
      // Check if it's a very round number (likely deposit)
      if(MathAbs(profit) >= 100)
      {
         if(MathMod(MathAbs(profit), 100) == 0 || MathMod(MathAbs(profit), 1000) == 0)
         {
            Print("Balance operation detected by ROUND NUMBER: ", profit);
            return true;
         }
      }
   }
   
   return false;
}

void AnalyzeAccountHistory()
{
   Print("Analyzing complete account history...");
   
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   int totalOrders = OrdersHistoryTotal();
   
   double tradesProfitSum = 0;
   totalDeposits = 0;
   totalWithdrawals = 0;
   int realTradesCount = 0;
   int balanceOpsCount = 0;
   
   for(int i = 0; i < totalOrders; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate)
         {
            if(IsBalanceOperation(i))
            {
               // This is a balance operation
               double amount = OrderProfit();
               if(amount > 0)
               {
                  totalDeposits += amount;
                  Print("→ DEPOSIT: $", DoubleToString(amount, 2), " [", OrderComment(), "]");
               }
               else if(amount < 0)
               {
                  totalWithdrawals += MathAbs(amount);
                  Print("→ WITHDRAWAL: $", DoubleToString(MathAbs(amount), 2), " [", OrderComment(), "]");
               }
               balanceOpsCount++;
            }
            else
            {
               // This is a real trade
               tradesProfitSum += OrderProfit() + OrderSwap() + OrderCommission();
               realTradesCount++;
            }
         }
      }
   }
   
   // Calculate initial balance
   // Formula: Current Balance - Real Trades Profit - Deposits + Withdrawals
   initialBalance = AccountBalance() - tradesProfitSum - totalDeposits + totalWithdrawals;
   
   if(initialBalance < 10)
   {
      // Fallback if calculation seems wrong
      initialBalance = AccountBalance() - tradesProfitSum;
      if(initialBalance < 10) initialBalance = 1000;
      Print("WARNING: Used fallback for initial balance calculation");
   }
   
   Print("=== ACCOUNT ANALYSIS COMPLETE ===");
   Print("Total Orders Processed: ", totalOrders);
   Print("Real Trades Found: ", realTradesCount);
   Print("Balance Operations Found: ", balanceOpsCount);
   Print("---");
   Print("Initial Balance: $", DoubleToString(initialBalance, 2));
   Print("Total Deposits: $", DoubleToString(totalDeposits, 2));
   Print("Total Withdrawals: $", DoubleToString(totalWithdrawals, 2));
   Print("Real Trades Profit: $", DoubleToString(tradesProfitSum, 2));
   Print("Current Balance: $", DoubleToString(AccountBalance(), 2));
   Print("Current Equity: $", DoubleToString(AccountEquity(), 2));
   Print("=================================");
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
   
   // Send ONLY real trades (skip balance operations)
   json += "\"trades\":[";
   int totalTrades = OrdersHistoryTotal();
   int count = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate)
         {
            // Skip balance operations
            if(IsBalanceOperation(i))
               continue;
            
            // Only send BUY/SELL trades
            int orderType = OrderType();
            if(orderType > 1) continue; // Skip pending/cancelled orders
            
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
   int openCount = 0;
   
   for(int i = 0; i < totalOpen; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         int orderType = OrderType();
         if(orderType <= 1) // Only BUY/SELL
         {
            if(openCount > 0) json += ",";
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
            openCount++;
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
      Print("✓ Batch sent: ", count, " trades, ", openCount, " open");
   else if(res == -1)
      Print("✗ WebRequest ERROR! Add URL to allowed list!");
   else
      Print("✗ Server error: ", res);
}

string GetOrderTypeStr()
{
   int type = OrderType();
   if(type == 0) return "BUY";
   if(type == 1) return "SELL";
   return "UNKNOWN";
}
