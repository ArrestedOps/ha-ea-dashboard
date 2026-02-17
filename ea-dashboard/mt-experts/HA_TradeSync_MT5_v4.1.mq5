//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT5_v4.1.mq5 |
//|                                                      MT5 VERSION  |
//+------------------------------------------------------------------+
#property version   "4.10"
#property strict

input string WebhookURL = "http://api.dobko.it/api/webhook/batch";
input string SecretKey = "your_secret";
input string EAName = "My EA MT5";
input string Category = "live";
input int HistoryDays = 365;
input int LiveTradesIntervalSec = 10;

datetime lastCheck = 0;
double initialBalance = 0;
double totalDeposits = 0;
double totalWithdrawals = 0;

int OnInit()
{
   Print("=== EA Dashboard v4.1 MT5 ===");
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

bool IsBalanceOperation()
{
   // MT5: Check deal type
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(0, DEAL_TYPE);
   
   // DEAL_TYPE_BALANCE = 2, DEAL_TYPE_CREDIT = 3
   if(dealType == 2 || dealType == 3)
      return true;
   
   return false;
}

void AnalyzeAccountHistory()
{
   Print("Analyzing MT5 account...");
   
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   HistorySelect(startDate, TimeCurrent());
   
   double tradesProfitSum = 0;
   totalDeposits = 0;
   totalWithdrawals = 0;
   int realTradesCount = 0;
   int balanceOpsCount = 0;
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         
         if(dealType == 2 || dealType == 3) // Balance or Credit
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(profit > 0)
               totalDeposits += profit;
            else if(profit < 0)
               totalWithdrawals += MathAbs(profit);
            balanceOpsCount++;
         }
         else if(dealType == 0 || dealType == 1) // Buy or Sell
         {
            tradesProfitSum += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            tradesProfitSum += HistoryDealGetDouble(ticket, DEAL_SWAP);
            tradesProfitSum += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            realTradesCount++;
         }
      }
   }
   
   initialBalance = totalDeposits > 0 ? 0 : (AccountInfoDouble(ACCOUNT_BALANCE) - tradesProfitSum);
   if(initialBalance < 0) initialBalance = 0;
   
   Print("=== MT5 ANALYSIS ===");
   Print("Broker: ", AccountInfoString(ACCOUNT_COMPANY));
   Print("Real Trades: ", realTradesCount);
   Print("Balance Ops: ", balanceOpsCount);
   Print("Initial: $", DoubleToString(initialBalance, 2));
   Print("Deposits: $", DoubleToString(totalDeposits, 2));
   Print("Withdrawals: $", DoubleToString(totalWithdrawals, 2));
   Print("Profit: $", DoubleToString(tradesProfitSum, 2));
   Print("====================");
}

void SendBatchData()
{
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   HistorySelect(startDate, TimeCurrent());
   
   string json = "{";
   json += "\"secret\":\"" + SecretKey + "\",";
   json += "\"account_number\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ",";
   json += "\"ea_name\":\"" + EAName + "\",";
   json += "\"broker\":\"" + AccountInfoString(ACCOUNT_COMPANY) + "\",";
   json += "\"platform\":\"MT5\",";
   json += "\"category\":\"" + Category + "\",";
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"current_balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + ",";
   json += "\"current_equity\":" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + ",";
   json += "\"total_deposits\":" + DoubleToString(totalDeposits, 2) + ",";
   json += "\"total_withdrawals\":" + DoubleToString(totalWithdrawals, 2) + ",";
   json += "\"currency\":\"USD\",";
   json += "\"leverage\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)) + ",";
   
   json += "\"trades\":[";
   int totalDeals = HistoryDealsTotal();
   int count = 0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         
         if(dealType == 2 || dealType == 3) continue; // Skip balance ops
         if(dealType != 0 && dealType != 1) continue; // Only Buy/Sell
         
         if(count > 0) json += ",";
         json += "{";
         json += "\"trade_id\":" + IntegerToString((int)ticket) + ",";
         json += "\"symbol\":\"" + HistoryDealGetString(ticket, DEAL_SYMBOL) + "\",";
         json += "\"type\":\"" + (dealType == 0 ? "BUY" : "SELL") + "\",";
         json += "\"lots\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_VOLUME), 2) + ",";
         json += "\"open_price\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), 5) + ",";
         json += "\"close_price\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), 5) + ",";
         json += "\"open_time\":\"" + TimeToString((datetime)HistoryDealGetInteger(ticket, DEAL_TIME), TIME_DATE|TIME_MINUTES) + "\",";
         json += "\"close_time\":\"" + TimeToString((datetime)HistoryDealGetInteger(ticket, DEAL_TIME), TIME_DATE|TIME_MINUTES) + "\",";
         json += "\"profit\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION), 2) + ",";
         json += "\"swap\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_SWAP), 2) + ",";
         json += "\"commission\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_COMMISSION), 2);
         json += "}";
         count++;
      }
   }
   json += "],";
   
   json += "\"open_trades\":[";
   int totalOpen = PositionsTotal();
   int openCount = 0;
   
   for(int i = 0; i < totalOpen; i++)
   {
      ulong posTicket = PositionGetTicket(i);
      if(posTicket > 0)
      {
         if(openCount > 0) json += ",";
         json += "{";
         json += "\"trade_id\":" + IntegerToString((int)posTicket) + ",";
         json += "\"symbol\":\"" + PositionGetString(POSITION_SYMBOL) + "\",";
         json += "\"type\":\"" + (PositionGetInteger(POSITION_TYPE) == 0 ? "BUY" : "SELL") + "\",";
         json += "\"lots\":" + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + ",";
         json += "\"open_price\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 5) + ",";
         json += "\"current_price\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), 5) + ",";
         json += "\"open_time\":\"" + TimeToString((datetime)PositionGetInteger(POSITION_TIME), TIME_DATE|TIME_MINUTES) + "\",";
         json += "\"profit\":" + DoubleToString(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP), 2);
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
      Print("✗ ERROR: Add URL!");
   else
      Print("✗ Server: ", res);
}
