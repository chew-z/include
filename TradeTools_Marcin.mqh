//+------------------------------------------------------------------+
//|                                           TradeTools.mq4 |
//|                        Copyright 2012, 2013 chew-z |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2012 chew-z"
#property link      "Trade tools (c) 2012 chew-z"
// extern bool ECN = false;
extern double  maxLots = 0.10;
extern int     maxContracts = 1;

extern int T = 5;               // badana liczba świec pod kątem trendu
extern int K = 4;               // liczba świec zgodnych z kierunkiem trendu
extern int Expiration = 45; // On Stop Order Expiration in minutes
extern int Bar_size = 10;   // Minimum bar size in pips
extern bool With_trend = true; // if true the position is in the trend direction (buy after white candle(s)), if false the position is anti-trend (sell after white candle(s))

extern double    Pending = 12; // pullback size in pips - On Stop 
extern int          SL = 25;
extern int          TP = 18;

extern bool    SendAlerts = true;
extern bool    SendNotifications   = true;        // Send iPhone notification to mobile MQL client
extern string  AlertEmailSubject   = "";          // Empty subject = don't send emails

int         pips2points;
double   pips2dbl;          // Stoploss 15 pips    0.015      0.0150
int         Digits_pips;      // DoubleToStr(dbl/pips2dbl, Digits.pips)
/////////////////////////// SIGNALS ////////////////////////////////////

bool isTrend_H(int T1, int K1) { // w zakresie T1 świec powinno być K1 świec wzrostowych
int k = 0;
      for(int i=T1; i > 0; i--) {
          if(Close[i] - Open[i] > Bar_size * pips2dbl)
            k++;
      }
      if (k >= K1)
        return(true);
return(false);
}

bool isTrend_L(int T1, int K1) { // w zakresie T1 powinno być K1 świec spadkowych
int k = 0;
      for(int i=T1; i > 0; i--) {
          if(Open[i] - Close[i] > Bar_size * pips2dbl)
            k++;
      }
      if (k >= K1)
        return(true);
return(false);
}

/////////////////////////// POMOCNICZE /////////////////////////////////
// On Stop Orders
int f_SendOrders_OnStop(int mode, int contracts, double Lots, double StopLoss, double TakeProfit, int magic_number, string oComment) {
int e, check = 0;
int ticket = 0; 
double price = 0.0;
color arrow = Red;
   if (mode == OP_BUYSTOP) arrow = Green;
   for(int cnt=contracts; cnt>=1; cnt--) {
          if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);
          RefreshRates(); // dodatkowe refresh
         if (mode == OP_BUYSTOP) price = NormalizeDouble(Close[1] + Pending*pips2dbl, Digits); else price = NormalizeDouble(Close[1] - Pending*pips2dbl, Digits);       
         ticket=OrderSend(Symbol(), mode, Lots, price, 3*pips2points, StopLoss, TakeProfit, oComment, magic_number, Time[0] + Expiration * 60, arrow);
         e = GetLastError();
         TradeIsNotBusy();
         if (e > 0)  check = e;
   } // for OrderSend()
return(check);
}

int f_OrdersCount(int magic_number) {
int counter = 0;
  for(int ct=OrdersTotal()-1;ct>=0;ct--) {
         if(OrderSelect(ct, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && OrderMagicNumber()  == magic_number )
            counter++;
  }
return(counter);
}

void f_SendAlerts(string AlertText) {
   if (SendAlerts) { 
      if (AlertEmailSubject > "") SendMail(AlertEmailSubject, AlertText);
      if(SendNotifications) SendNotification(AlertText);
      Alert(AlertText); 
      Print(AlertText);
   }
}

string TFToStr(int tf)   {                                                                                    
  if (tf == 0)        tf = Period();                                                                          
  if (tf >= 43200)    return("MN");                                                                           
  if (tf >= 10080)    return("W1");                                                                           
  if (tf >=  1440)    return("D1");                                                                           
  if (tf >=   240)    return("H4");                                                                           
  if (tf >=    60)    return("H1");                                                                           
  if (tf >=    30)    return("M30");                                                                          
  if (tf >=    15)    return("M15");                                                                          
  if (tf >=     5)    return("M5");                                                                           
  if (tf >=     1)    return("M1");                                                                           
  return("");                                                                                                 
}

 