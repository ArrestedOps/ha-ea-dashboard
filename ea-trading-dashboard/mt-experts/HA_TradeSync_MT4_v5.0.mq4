//+------------------------------------------------------------------+
//|                                      HA_TradeSync_MT4_v5.0.mq4   |
//|                        EA Trading Dashboard v5.0 - Home Assistant|
//|                                         Webhook Integration      |
//+------------------------------------------------------------------+
#property copyright "EA Dashboard v5.0"
#property link      "https://github.com/yourusername/ea-dashboard"
#property version   "5.00"
#property strict

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
   json += "\"account_number\":" + IntegerToString(AccountNumber()) + ",";
   json += "\"ea_name\":\"" + EAName + "\",";
   json += "\"broker\":\"" + AccountCompany() + "\",";
   json += "\"platform\":\"MT4\",";
   json += "\"category\":\"" + categoryStrings[AccountCategory] + "\",";
   json += "\"currency\":\"" + AccountCurrency() + "\",";
   json += "\"current_balance\":" + DoubleToString(AccountBalance(), 2) + ",";
   json += "\"total_deposits\":" + DoubleToString(AccountEquity(), 2) + ",";
   json += "\"leverage\":" + IntegerToString(AccountLeverage()) + ",";
   
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
   int total = OrdersHistoryTotal();
   int count = 0;
   
   for(int i = total - 1; i >= 0 && count < 100; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderType() > 1) continue; // Skip pending orders
      
      // Only trades since start date
      if(OrderCloseTime() < StartDate) continue;
      
      if(trades != "") trades += ",";
      
      trades += "{";
      trades += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
      trades += "\"symbol\":\"" + OrderSymbol() + "\",";
      trades += "\"type\":\"" + (OrderType() == OP_BUY ? "BUY" : "SELL") + "\",";
      trades += "\"volume\":" + DoubleToString(OrderLots(), 2) + ",";
      trades += "\"open_price\":" + DoubleToString(OrderOpenPrice(), 5) + ",";
      trades += "\"close_price\":" + DoubleToString(OrderClosePrice(), 5) + ",";
      trades += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2) + ",";
      trades += "\"open_time\":\"" + TimeToString(OrderOpenTime(), TIME_DATE|TIME_SECONDS) + "\",";
      trades += "\"close_time\":\"" + TimeToString(OrderCloseTime(), TIME_DATE|TIME_SECONDS) + "\"";
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
   int total = OrdersTotal();
   
   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() > 1) continue; // Skip pending orders
      
      if(trades != "") trades += ",";
      
      trades += "{";
      trades += "\"trade_id\":" + IntegerToString(OrderTicket()) + ",";
      trades += "\"symbol\":\"" + OrderSymbol() + "\",";
      trades += "\"type\":\"" + (OrderType() == OP_BUY ? "BUY" : "SELL") + "\",";
      trades += "\"volume\":" + DoubleToString(OrderLots(), 2) + ",";
      trades += "\"open_price\":" + DoubleToString(OrderOpenPrice(), 5) + ",";
      trades += "\"profit\":" + DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2) + ",";
      trades += "\"open_time\":\"" + TimeToString(OrderOpenTime(), TIME_DATE|TIME_SECONDS) + "\"";
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
