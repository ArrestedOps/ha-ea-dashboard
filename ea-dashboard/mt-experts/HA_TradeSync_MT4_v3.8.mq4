//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v3.8.mq4 |
//|                    CONSERVATIVE: Only filter OrderType 6/7       |
//+------------------------------------------------------------------+
#property version   "3.80"
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
   Print("=== EA Dashboard v3.8 - CONSERVATIVE FILTERING ===");
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
   
   // ONLY check OrderType - most reliable method
   int orderType = OrderType();
   
   // OrderType 6 = Balance, 7 = Credit
   if(orderType == 6 || orderType == 7)
   {
      Print("→ Balance Op (Type ", orderType, "): ", OrderComment());
      return true;
   }
   
   // DO NOT filter by comment! Comments can be misleading
   // Only filter by type to be safe
   
   return false;
}

void AnalyzeAccountHistory()
{
   Print("Analyzing account (OrderType-based filtering only)...");
   
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
            else if(OrderType() <= 1) // Only BUY/SELL
            {
               tradesProfitSum += OrderProfit() + OrderSwap() + OrderCommission();
               realTradesCount++;
            }
         }
      }
   }
   
   initialBalance = AccountBalance() - tradesProfitSum - totalDeposits + totalWithdrawals;
   if(initialBalance < 10) initialBalance = 1000;
   
   Print("=== ANALYSIS ===");
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
         if(OrderCloseTime() >= startDate)
         {
            if(IsBalanceOperation(i))
               continue;
            
            int orderType = OrderType();
            if(orderType > 1) continue; // Skip pending
            
            if(count > 0) json += ",";
            json += "{";
            json += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
            json += "\"symbol\":\"" + OrderSymbol() + "\",";
            json += "\"type\":\"" + (orderType == 0 ? "BUY" : "SELL") + "\",";
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
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderType() <= 1)
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
   }
   json += "]}";
   
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
   int res = WebRequest("POST", WebhookURL, headers, 5000, post, result, result_headers);
   
   if(res == 200)
      Print("✓ Sent: ", count, " trades, ", openCount, " open");
   else if(res == -1)
      Print("✗ WebRequest ERROR!");
   else
      Print("✗ Server: ", res);
}
