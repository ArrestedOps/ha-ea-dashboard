//+------------------------------------------------------------------+
//|                                        HA_TradeSync_MT5_v4.8.mq5 |
//+------------------------------------------------------------------+
#property version "4.80"

input string WebhookURL  = "http://api.dobko.it/api/webhook/batch";
input string SecretKey   = "your_secret";
input string EAName      = "My EA MT5";
input string Category    = "live";
input int    HistoryDays = 365;
input int    UpdateSec   = 10;

datetime lastSent = 0;
double   gDeposits = 0;
double   gWithdraw = 0;

int OnInit() { Print("HA TradeSync MT5 v4.8.0"); ScanHistory(); SendData(); return INIT_SUCCEEDED; }
void OnDeinit(const int r) {}
void OnTick() { if(TimeCurrent()-lastSent>=UpdateSec){ SendData(); lastSent=TimeCurrent(); } }

void ScanHistory()
{
   gDeposits=0; gWithdraw=0;
   datetime from=TimeCurrent()-HistoryDays*86400;
   HistorySelect(from,TimeCurrent());
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong tk=HistoryDealGetTicket(i);
      if(!tk) continue;
      ENUM_DEAL_TYPE dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(tk,DEAL_TYPE);
      double profit=HistoryDealGetDouble(tk,DEAL_PROFIT);
      if(dt==DEAL_TYPE_BALANCE||dt==DEAL_TYPE_CREDIT)
      {
         if(profit>0) gDeposits+=profit; else gWithdraw+=MathAbs(profit);
      }
   }
   Print("MT5 Deposits=$",DoubleToString(gDeposits,2)," Withdrawals=$",DoubleToString(gWithdraw,2));
}

string EJ(string s){StringReplace(s,"\"","'");return s;}

void SendData()
{
   datetime from=TimeCurrent()-HistoryDays*86400;
   HistorySelect(from,TimeCurrent());
   string j="{";
   j+="\"secret\":\""+SecretKey+"\",";
   j+="\"account_number\":"+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN))+",";
   j+="\"ea_name\":\""+EJ(EAName)+"\",";
   j+="\"broker\":\""+EJ(AccountInfoString(ACCOUNT_COMPANY))+"\",";
   j+="\"platform\":\"MT5\",";
   j+="\"category\":\""+Category+"\",";
   j+="\"initial_balance\":0,";
   j+="\"current_balance\":"+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)+",";
   j+="\"current_equity\":"+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)+",";
   j+="\"total_deposits\":"+DoubleToString(gDeposits,2)+",";
   j+="\"total_withdrawals\":"+DoubleToString(gWithdraw,2)+",";
   j+="\"currency\":\""+AccountInfoString(ACCOUNT_CURRENCY)+"\",";
   j+="\"leverage\":"+IntegerToString((int)AccountInfoInteger(ACCOUNT_LEVERAGE))+",";
   j+="\"trades\":[";
   int n=HistoryDealsTotal(),cnt=0;
   for(int i=0;i<n;i++)
   {
      ulong tk=HistoryDealGetTicket(i);
      if(!tk) continue;
      ENUM_DEAL_TYPE dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(tk,DEAL_TYPE);
      if(dt!=DEAL_TYPE_BUY&&dt!=DEAL_TYPE_SELL) continue;
      ENUM_DEAL_ENTRY de=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk,DEAL_ENTRY);
      if(de!=DEAL_ENTRY_OUT&&de!=DEAL_ENTRY_INOUT) continue;
      if(cnt) j+=",";
      j+="{\"trade_id\":"+IntegerToString((int)tk)
        +",\"symbol\":\""+EJ(HistoryDealGetString(tk,DEAL_SYMBOL))+"\""
        +",\"type\":\""+(dt==DEAL_TYPE_BUY?"BUY":"SELL")+"\""
        +",\"lots\":"+DoubleToString(HistoryDealGetDouble(tk,DEAL_VOLUME),2)
        +",\"open_price\":"+DoubleToString(HistoryDealGetDouble(tk,DEAL_PRICE),5)
        +",\"close_price\":"+DoubleToString(HistoryDealGetDouble(tk,DEAL_PRICE),5)
        +",\"open_time\":\""+TimeToString((datetime)HistoryDealGetInteger(tk,DEAL_TIME),TIME_DATE|TIME_MINUTES)+"\""
        +",\"close_time\":\""+TimeToString((datetime)HistoryDealGetInteger(tk,DEAL_TIME),TIME_DATE|TIME_MINUTES)+"\""
        +",\"profit\":"+DoubleToString(HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION),2)
        +",\"swap\":"+DoubleToString(HistoryDealGetDouble(tk,DEAL_SWAP),2)
        +",\"commission\":"+DoubleToString(HistoryDealGetDouble(tk,DEAL_COMMISSION),2)
        +"}";
      cnt++;
   }
   j+="],\"open_trades\":[";
   int m=PositionsTotal(),oc=0;
   for(int i=0;i<m;i++)
   {
      ulong pt=PositionGetTicket(i);
      if(!pt) continue;
      if(oc) j+=",";
      j+="{\"trade_id\":"+IntegerToString((int)pt)
        +",\"symbol\":\""+EJ(PositionGetString(POSITION_SYMBOL))+"\""
        +",\"type\":\""+(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"BUY":"SELL")+"\""
        +",\"lots\":"+DoubleToString(PositionGetDouble(POSITION_VOLUME),2)
        +",\"open_price\":"+DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),5)
        +",\"current_price\":"+DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT),5)
        +",\"open_time\":\""+TimeToString((datetime)PositionGetInteger(POSITION_TIME),TIME_DATE|TIME_MINUTES)+"\""
        +",\"profit\":"+DoubleToString(PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),2)
        +"}";
      oc++;
   }
   j+="]}";
   string hdr="Content-Type: application/json\r\n";
   char post[],res[];string rHdr;
   ArrayResize(post,StringToCharArray(j,post,0,WHOLE_ARRAY)-1);
   int rc=WebRequest("POST",WebhookURL,hdr,5000,post,res,rHdr);
   if(rc==200) Print("✓ MT5: ",cnt," trades");
   else if(rc==-1) Print("✗ Add URL!");
   else Print("✗ HTTP ",rc);
}
