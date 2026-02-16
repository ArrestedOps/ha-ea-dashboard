//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT5_v3.2.mq5 |
//|                                   EA Trading Dashboard Sync v3.2 |
//+------------------------------------------------------------------+
#property copyright "EA Trading Dashboard v3.2"
#property link      "https://github.com/ArrestedOps/ha-ea-dashboard"
#property version   "3.20"

// --- Input Parameters ---
input string WebhookURL = "http://api.dobko.it/api/webhook/trade";
input string SecretKey = "your_secret_key_here";
input string EAName = "My EA";
input string Category = "live";
input bool SendHistory = true;
input int HistoryDays = 90;
input int CheckIntervalSeconds = 10;

// --- Global Variables ---
datetime lastCheck = 0;
double initialBalance = 0;
bool initialized = false;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== EA Trading Dashboard Sync v3.2 (MT5) Starting ===");
   
   if(SendHistory && HistoryDays > 0)
   {
      CalculateInitialBalance();
      SendTradeHistory();
   }
   else
   {
      initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   SendLiveTrades();
   initialized = true;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA Trading Dashboard Sync stopped");
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(TimeCurrent() - lastCheck >= CheckIntervalSeconds)
   {
      SendLiveTrades();
      lastCheck = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
void CalculateInitialBalance()
{
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   HistorySelect(startDate, TimeCurrent());
   
   int totalDeals = HistoryDealsTotal();
   if(totalDeals == 0)
   {
      initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      return;
   }
   
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         initialBalance -= HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }
   }
   
   if(initialBalance < 100) initialBalance = 1000;
   Print("Calculated Initial Balance: ", initialBalance);
}

//+------------------------------------------------------------------+
void SendTradeHistory()
{
   Print("Sending trade history...");
   datetime startDate = TimeCurrent() - (HistoryDays * 86400);
   HistorySelect(startDate, TimeCurrent());
   
   int totalDeals = HistoryDealsTotal();
   int sentCount = 0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         SendDeal(ticket);
         sentCount++;
         Sleep(50);
      }
   }
   
   Print("Sent ", sentCount, " historical trades");
}

//+------------------------------------------------------------------+
void SendLiveTrades()
{
   int total = PositionsTotal();
   if(total == 0) return;
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         SendPosition(ticket);
      }
   }
}

//+------------------------------------------------------------------+
void SendDeal(ulong ticket)
{
   if(!HistoryDealSelect(ticket)) return;
   
   string json = "{";
   json += "\"secret\":\"" + SecretKey + "\",";
   json += "\"account_number\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ",";
   json += "\"ea_name\":\"" + EAName + "\",";
   json += "\"broker\":\"" + AccountInfoString(ACCOUNT_COMPANY) + "\",";
   json += "\"platform\":\"MT5\",";
   json += "\"category\":\"" + Category + "\",";
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"trade\":{";
   json += "\"trade_id\":" + IntegerToString(ticket) + ",";
   json += "\"symbol\":\"" + HistoryDealGetString(ticket, DEAL_SYMBOL) + "\",";
   json += "\"type\":\"" + GetDealType(ticket) + "\",";
   json += "\"lots\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_VOLUME), 2) + ",";
   json += "\"profit\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PROFIT), 2) + ",";
   json += "\"close_time\":\"" + TimeToString((datetime)HistoryDealGetInteger(ticket, DEAL_TIME), TIME_DATE|TIME_MINUTES) + "\",";
   json += "\"balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   json += "}}";
   
   SendWebRequest(json);
}

//+------------------------------------------------------------------+
void SendPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   string json = "{";
   json += "\"secret\":\"" + SecretKey + "\",";
   json += "\"account_number\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ",";
   json += "\"ea_name\":\"" + EAName + "\",";
   json += "\"broker\":\"" + AccountInfoString(ACCOUNT_COMPANY) + "\",";
   json += "\"platform\":\"MT5\",";
   json += "\"category\":\"" + Category + "\",";
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"open_trade\":{";
   json += "\"trade_id\":" + IntegerToString(ticket) + ",";
   json += "\"symbol\":\"" + PositionGetString(POSITION_SYMBOL) + "\",";
   json += "\"type\":\"" + GetPositionType() + "\",";
   json += "\"lots\":" + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + ",";
   json += "\"profit\":" + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2) + ",";
   json += "\"open_time\":\"" + TimeToString((datetime)PositionGetInteger(POSITION_TIME), TIME_DATE|TIME_MINUTES) + "\",";
   json += "\"balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   json += "}}";
   
   SendWebRequest(json);
}

//+------------------------------------------------------------------+
void SendWebRequest(string json)
{
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
   
   int res = WebRequest("POST", WebhookURL, headers, 5000, post, result, result_headers);
   
   if(res != 200 && res != -1)
   {
      Print("Server response: ", res);
   }
}

//+------------------------------------------------------------------+
string GetDealType(ulong ticket)
{
   long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
   if(type == DEAL_TYPE_BUY) return "BUY";
   if(type == DEAL_TYPE_SELL) return "SELL";
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
string GetPositionType()
{
   long type = PositionGetInteger(POSITION_TYPE);
   if(type == POSITION_TYPE_BUY) return "BUY";
   if(type == POSITION_TYPE_SELL) return "SELL";
   return "UNKNOWN";
}
//+------------------------------------------------------------------+
