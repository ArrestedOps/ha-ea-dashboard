//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v3.9.mq4 |
//|                    SMART: Multi-broker balance detection         |
//+------------------------------------------------------------------+
#property version   "3.90"
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
   Print("=== EA Dashboard v3.9 - SMART BALANCE DETECTION ===");
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
   
   int orderType = OrderType();
   string comment = OrderComment();
   StringToLower(comment);
   double profit = OrderProfit();
   double swap = OrderSwap();
   double commission = OrderCommission();
   
   // Method 1: OrderType (LiteFinance, etc.)
   if(orderType == 6 || orderType == 7)
      return true;
   
   // Method 2: Comment with "balance" keyword
   if(StringFind(comment, "balance") >= 0)
      return true;
   
   // Method 3: Large round deposit (Black Bull, etc.)
   // Must be: BUY/SELL type, no swap, no commission, large round number
   if(orderType <= 1 && swap == 0 && commission == 0 && MathAbs(profit) >= 1000)
   {
      // Check if it's a round number
      double absProfit = MathAbs(profit);
      if(MathMod(absProfit, 1000) == 0 || MathMod(absProfit, 500) == 0)
      {
         Print("→ Deposit detected (round): $", DoubleToString(profit, 2));
         return true;
      }
   }
   
   return false;
}

void AnalyzeAccountHistory()
{
   Print("Analyzing (smart multi-broker detection)...");
   
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
               double amount = OrderProfit();
               if(amount > 0)
                  totalDeposits += amount;
               else if(amount < 0)
                  totalWithdrawals += MathAbs(amount);
               balanceOpsCount++;
            }
            else if(OrderType() <= 1)
            {
               tradesProfitSum += OrderProfit() + OrderSwap() + OrderCommission();
               realTradesCount++;
            }
         }
      }
   }
   
   initialBalance = AccountBalance() - tradesProfitSum - totalDeposits + totalWithdrawals;
   if(initialBalance < 10) initialBalance = 0;
   
   Print("=== ANALYSIS ===");
   Print("Broker: ", AccountCompany());
   Print("Real Trades: ", realTradesCount);
   Print("Balance Ops: ", balanceOpsCount);
   Print("Initial: $", DoubleToString(initialBalance, 2));
   Print("Deposits: $", DoubleToString(totalDeposits, 2));
   Print("Withdrawals: $", DoubleToString(totalWithdrawals, 2));
   Print("Profit: $", DoubleToString(tradesProfitSum, 2));
   Print("================");
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
   
   json += "\"trades\":[";
   int totalTrades = OrdersHistoryTotal();
   int count = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderCloseTime() >= startDate && OrderType() <= 1)
         {
            if(IsBalanceOperation(i))
               continue;
            
            if(count > 0) json += ",";
            json += "{";
            json += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
            json += "\"symbol\":\"" + OrderSymbol() + "\",";
            json += "\"type\":\"" + (OrderType() == 0 ? "BUY" : "SELL") + "\",";
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
   
   json += "\"open_trades\":[";
   int totalOpen = OrdersTotal();
   int openCount = 0;
   
   for(int i = 0; i < totalOpen; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderType() <= 1)
      {
         if(openCount > 0) json += ",";
         json += "{";
         json += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
         json += "\"symbol\":\"" + OrderSymbol() + "\",";
         json += "\"type\":\"" + (OrderType() == 0 ? "BUY" : "SELL") + "\",";
         json += "\"lots\":" + DoubleToString(OrderLots(), 2) + ",";
         json += "\"open_price\":" + DoubleToString(OrderOpenPrice(), 5) + ",";
         json += "\"current_price\":" + DoubleToString(OrderClosePrice(), 5) + ",";
         json += "\"open_time\":\"" + TimeToStr(OrderOpenTime(), TIME_DATE|TIME_MINUTES) + "\",";
         json += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2);
         json += "}";
         openCount++;
      }
   }
   json += "]}";
   
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
   int res = WebRequest("POST", WebhookURL, headers, 5000, post, result, result_headers);
   
   if(res == 200)
      Print("✓ OK: ", count, " trades");
   else if(res == -1)
      Print("✗ ERROR!");
   else
      Print("✗ Server: ", res);
}
