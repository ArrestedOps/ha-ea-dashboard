//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT4_v4.0.mq4 |
//|                              FINAL PERFECT - Based on statements |
//+------------------------------------------------------------------+
#property version   "4.00"
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
   Print("=== EA Dashboard v4.0 - FINAL PERFECT ===");
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
   
   // CRITICAL: Both brokers use OrderType 6 for balance operations
   // Black Bull: Type=6, Comment="Transfer_from_206835_Wallet"
   // LiteFinance: Type=6, Comment="DPST-IT-5208013: USD 2000.00"
   
   if(orderType == 6 || orderType == 7) // Balance or Credit
      return true;
   
   return false;
}

void AnalyzeAccountHistory()
{
   Print("Analyzing account history...");
   
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
            else if(OrderType() <= 1) // Only BUY/SELL
            {
               tradesProfitSum += OrderProfit() + OrderSwap() + OrderCommission();
               realTradesCount++;
            }
         }
      }
   }
   
   // Calculate initial balance
   initialBalance = totalDeposits > 0 ? 0 : (AccountBalance() - tradesProfitSum);
   
   if(initialBalance < 0) initialBalance = 0;
   
   Print("=== FINAL ANALYSIS ===");
   Print("Broker: ", AccountCompany());
   Print("Real Trades: ", realTradesCount);
   Print("Balance Operations: ", balanceOpsCount);
   Print("---");
   Print("Initial Balance: $", DoubleToString(initialBalance, 2));
   Print("Total Deposits: $", DoubleToString(totalDeposits, 2));
   Print("Total Withdrawals: $", DoubleToString(totalWithdrawals, 2));
   Print("Trades Profit: $", DoubleToString(tradesProfitSum, 2));
   Print("Current Balance: $", DoubleToString(AccountBalance(), 2));
   Print("======================");
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
      Print("✓ Success: ", count, " trades sent");
   else if(res == -1)
      Print("✗ ERROR: Add URL to allowed list!");
   else
      Print("✗ Server error: ", res);
}
