//+------------------------------------------------------------------+
//|                                      HA_TradeSync_MT5_v5.0.mq5   |
//|                        EA Trading Dashboard v5.0 - Home Assistant|
//|                                         Webhook Integration      |
//+------------------------------------------------------------------+
#property copyright "EA Dashboard v5.0"
#property link      "https://github.com/yourusername/ea-dashboard"
#property version   "5.00"

//--- Input Parameters
enum ENUM_ACCOUNT_CATEGORY
{
   CATEGORY_LIVE = 0,   // Live Account
   CATEGORY_COPY = 1,   // Copy Trading
   CATEGORY_DEMO = 2    // Demo Account
};

input string    WebhookURL = "http://homeassistant.local:8099/api/webhook"; // Webhook URL
input string    EAName = "EA Name";                                         // EA Name (Account Identifier)
input ENUM_ACCOUNT_CATEGORY AccountCategory = CATEGORY_DEMO;                // Account Category
input datetime  StartDate = D'2025.01.01 00:00';                           // Start Date (for calculations)
input int       WebhookInterval = 60;                                       // Webhook Interval (seconds)

//--- Global Variables
datetime lastWebhookTime = 0;
string categoryStrings[3] = {"live", "copy", "demo"};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== EA Dashboard v5.0 Initialized ===");
   Print("EA Name: ", EAName);
   Print("Category: ", categoryStrings[AccountCategory]);
   Print("Start Date: ", TimeToString(StartDate, TIME_DATE));
   Print("Webhook URL: ", WebhookURL);
   Print("Webhook Interval: ", WebhookInterval, " seconds");
   
   // Validate start date
   if(StartDate > TimeCurrent())
   {
      Print("ERROR: Start date is in the future!");
      return INIT_FAILED;
   }
   
   // Send initial webhook
   SendWebhook();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Send webhook at specified interval
   if(TimeCurrent() - lastWebhookTime >= WebhookInterval)
   {
      SendWebhook();
      lastWebhookTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Send webhook with account data                                   |
//+------------------------------------------------------------------+
void SendWebhook()
{
   string json = BuildJSON();
   
   // HTTP POST Request
   char postData[];
   char result[];
   string headers = "Content-Type: application/json\r\n";
   
   StringToCharArray(json, postData, 0, StringLen(json));
   
   int timeout = 5000;
   int res = WebRequest(
      "POST",
      WebhookURL,
      headers,
      timeout,
      postData,
      result,
      headers
   );
   
   if(res == 200)
   {
      Print("✓ Webhook sent successfully");
   }
   else if(res == -1)
   {
      int error = GetLastError();
      Print("ERROR: WebRequest failed. Error code: ", error);
      Print("Make sure URL is in Tools -> Options -> Expert Advisors -> Allow WebRequest for:");
      Print(WebhookURL);
   }
   else
   {
      Print("ERROR: HTTP ", res);
   }
}

//+------------------------------------------------------------------+
//| Build JSON payload                                               |
//+------------------------------------------------------------------+
string BuildJSON()
{
   string json = "{";
   
   // Account info
   json += "\"account_number\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ",";
   json += "\"ea_name\":\"" + EAName + "\",";
   json += "\"broker\":\"" + AccountInfoString(ACCOUNT_COMPANY) + "\",";
   json += "\"platform\":\"MT5\",";
   json += "\"category\":\"" + categoryStrings[AccountCategory] + "\",";
   json += "\"currency\":\"" + AccountInfoString(ACCOUNT_CURRENCY) + "\",";
   json += "\"current_balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + ",";
   json += "\"total_deposits\":" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + ",";
   json += "\"leverage\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)) + ",";
   
   // Start date (custom field for days calculation on backend)
   json += "\"start_date\":\"" + TimeToString(StartDate, TIME_DATE|TIME_SECONDS) + "\",";
   
   // Closed trades
   json += "\"trades\":[";
   json += GetClosedTrades();
   json += "],";
   
   // Open trades
   json += "\"open_trades\":[";
   json += GetOpenTrades();
   json += "]";
   
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Get closed trades                                                |
//+------------------------------------------------------------------+
string GetClosedTrades()
{
   string trades = "";
   int count = 0;
   
   // Select history
   HistorySelect(StartDate, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = total - 1; i >= 0 && count < 100; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      // Only real trades (not balance operations)
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      if(HistoryDealGetInteger(ticket, DEAL_TYPE) > 1) continue; // Only BUY/SELL
      
      ulong positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      
      // Get entry deal
      HistorySelectByPosition(positionId);
      ulong entryTicket = 0;
      double openPrice = 0;
      datetime openTime = 0;
      
      for(int j = 0; j < HistoryDealsTotal(); j++)
      {
         ulong dealTicket = HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            entryTicket = dealTicket;
            openPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            openTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            break;
         }
      }
      
      if(entryTicket == 0) continue;
      
      if(trades != "") trades += ",";
      
      trades += "{";
      trades += "\"trade_id\":" + IntegerToString(positionId) + ",";
      trades += "\"symbol\":\"" + HistoryDealGetString(ticket, DEAL_SYMBOL) + "\",";
      trades += "\"type\":\"" + (HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BUY ? "BUY" : "SELL") + "\",";
      trades += "\"volume\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_VOLUME), 2) + ",";
      trades += "\"open_price\":" + DoubleToString(openPrice, 5) + ",";
      trades += "\"close_price\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), 5) + ",";
      trades += "\"profit\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                                                HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                                                HistoryDealGetDouble(ticket, DEAL_COMMISSION), 2) + ",";
      trades += "\"open_time\":\"" + TimeToString(openTime, TIME_DATE|TIME_SECONDS) + "\",";
      trades += "\"close_time\":\"" + TimeToString((datetime)HistoryDealGetInteger(ticket, DEAL_TIME), TIME_DATE|TIME_SECONDS) + "\"";
      trades += "}";
      
      count++;
   }
   
   return trades;
}

//+------------------------------------------------------------------+
//| Get open trades                                                  |
//+------------------------------------------------------------------+
string GetOpenTrades()
{
   string trades = "";
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(trades != "") trades += ",";
      
      trades += "{";
      trades += "\"trade_id\":" + IntegerToString(PositionGetInteger(POSITION_IDENTIFIER)) + ",";
      trades += "\"symbol\":\"" + PositionGetString(POSITION_SYMBOL) + "\",";
      trades += "\"type\":\"" + (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL") + "\",";
      trades += "\"volume\":" + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + ",";
      trades += "\"open_price\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 5) + ",";
      trades += "\"profit\":" + DoubleToString(PositionGetDouble(POSITION_PROFIT) + 
                                                PositionGetDouble(POSITION_SWAP), 2) + ",";
      trades += "\"open_time\":\"" + TimeToString((datetime)PositionGetInteger(POSITION_TIME), TIME_DATE|TIME_SECONDS) + "\"";
      trades += "}";
   }
   
   return trades;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA Dashboard v5.0 stopped. Reason: ", reason);
}
//+------------------------------------------------------------------+
