//+------------------------------------------------------------------+
//|                                           HA_TradeSync_MT5.mq5   |
//|                                   Home Assistant Trade Sync EA   |
//|                         Sends trades to HA EA Dashboard via HTTP |
//+------------------------------------------------------------------+
#property copyright "EA Trading Dashboard"
#property link      "https://github.com/ArrestedOps/ha-ea-dashboard"
#property version   "2.00"

//--- Input Parameters
input string WebhookURL = "http://192.168.1.100:8099/api/webhook/trade";  // Home Assistant URL
input string SecretKey = "";                    // Webhook Secret (optional)
input string EAName = "My EA";                  // EA Name in Dashboard
input string Category = "live";                 // Category: live, demo, copy, challenge
input bool SendHistoryOnStart = true;           // Send trade history on start
input int HistoryDays = 90;                     // Days of history to send

//--- Global Variables
datetime lastCheck = 0;
int checkInterval = 5;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===========================================");
   Print("HA Trade Sync EA v2.0 Initialized (MT5)");
   Print("EA Name: ", EAName);
   Print("Category: ", Category);
   Print("Webhook URL: ", WebhookURL);
   Print("===========================================");
   
   if(SendHistoryOnStart)
   {
      Print("Sending trade history...");
      SendTradeHistory();
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("HA Trade Sync EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(TimeCurrent() - lastCheck >= checkInterval)
   {
      CheckClosedTrades();
      lastCheck = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Check for newly closed deals                                       |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   static int lastTotal = 0;
   
   HistorySelect(0, TimeCurrent());
   int currentTotal = HistoryDealsTotal();
   
   if(currentTotal > lastTotal)
   {
      for(int i = lastTotal; i < currentTotal; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
               SendDeal(ticket);
            }
         }
      }
      lastTotal = currentTotal;
   }
}

//+------------------------------------------------------------------+
//| Send trade history                                                 |
//+------------------------------------------------------------------+
void SendTradeHistory()
{
   datetime startDate = TimeCurrent() - (HistoryDays * 24 * 3600);
   HistorySelect(startDate, TimeCurrent());
   
   int sent = 0;
   int total = HistoryDealsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            if(SendDeal(ticket))
               sent++;
         }
      }
   }
   
   Print("Sent ", sent, " historical trades to dashboard");
}

//+------------------------------------------------------------------+
//| Send single deal to webhook                                        |
//+------------------------------------------------------------------+
bool SendDeal(ulong ticket)
{
   // Get deal info
   long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT)
      return false;
   
   long positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
   string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
   ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
   double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
   double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
   double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
   datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
   string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
   
   // Get entry deal for open time/price
   HistorySelectByPosition(positionId);
   datetime openTime = 0;
   double openPrice = 0;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         openTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         openPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         break;
      }
   }
   
   // Build JSON
   string json = "{";
   json += "\"secret\": \"" + SecretKey + "\",";
   json += "\"account_number\": " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ",";
   json += "\"ea_name\": \"" + EAName + "\",";
   json += "\"category\": \"" + Category + "\",";
   json += "\"platform\": \"MT5\",";
   json += "\"broker\": \"" + AccountInfoString(ACCOUNT_COMPANY) + "\",";
   json += "\"trade\": {";
   json += "\"trade_id\": \"" + IntegerToString(ticket) + "\",";
   json += "\"open_time\": \"" + TimeToString(openTime, TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"close_time\": \"" + TimeToString(time, TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"symbol\": \"" + symbol + "\",";
   json += "\"type\": \"" + (type == DEAL_TYPE_BUY ? "BUY" : "SELL") + "\",";
   json += "\"lots\": " + DoubleToString(volume, 2) + ",";
   json += "\"open_price\": " + DoubleToString(openPrice, 5) + ",";
   json += "\"close_price\": " + DoubleToString(price, 5) + ",";
   json += "\"profit\": " + DoubleToString(profit, 2) + ",";
   json += "\"commission\": " + DoubleToString(commission, 2) + ",";
   json += "\"swap\": " + DoubleToString(swap, 2) + ",";
   json += "\"balance\": " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + ",";
   json += "\"comment\": \"" + comment + "\"";
   json += "}}";
   
   // Send HTTP POST
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   int timeout = 5000;
   
   int res = WebRequest(
      "POST",
      WebhookURL,
      headers,
      timeout,
      post,
      result,
      headers
   );
   
   // Convert JSON to char array
   StringToCharArray(json, post, 0, StringLen(json));
   
   res = WebRequest("POST", WebhookURL, headers, timeout, post, result, headers);
   
   if(res == 200)
   {
      Print("✓ Trade #", ticket, " sent successfully");
      return true;
   }
   else
   {
      Print("✗ Failed to send trade #", ticket, ". Error: ", res);
      return false;
   }
}
//+------------------------------------------------------------------+
