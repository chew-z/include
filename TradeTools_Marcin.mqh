//+------------------------------------------------------------------+
//|                                           TradeTools.mq4 |
//|                                 Copyright 2012 chew-z |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2012 chew-z"
#property link      "Trade tools (c) 2012 chew-z"
extern bool ECN = false;
extern double  maxLots = 0.10;
extern int     maxContracts = 1;

extern double    Pending = 12; // pullback size in pips
extern int          SL = 25;
extern int          TP = 18;

extern bool    SendAlerts = true;
extern bool    SendNotifications   = true;        // Send iPhone notification to mobile MQL client
extern string  AlertEmailSubject   = "";          // Empty subject = don't send emails

int         pips2points;
double   pips2dbl;          // Stoploss 15 pips    0.015      0.0150
int         Digits.pips;      // DoubleToStr(dbl/pips2dbl, Digits.pips)
/////////////////////////// SIGNALS ////////////////////////////////////

bool isPullback_L() { // 

      if ( Close[1] > Open[1] && Close[1] - Ask > Pending * pips2dbl) //  Jeśli Pullback od zamknięcia świecy przekroczył X pips
         return(true);
return(false);
}

bool isPullback_S() { // 

      if (Close[1] < Open[1]  && Bid - Close[1] > Pending * pips2dbl ) //  Jeśli Pullback od zamknięcia świecy przekroczył X pips
         return(true);
return(false);
}

/////////////////////////// POMOCNICZE /////////////////////////////////
int f_SendOrders(int mode, int contracts, double Lots, double StopLoss, double TakeProfit, int magic_number, string oComment) {
int e, check = 0;
int ticket = 0; 
double price = 0.0;
color arrow = Red;
   if (mode == OP_BUY) arrow = Green;
   for(int cnt=contracts; cnt>=1; cnt--) {
          if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);
          RefreshRates(); // dodatkowe refresh
	       if (mode == OP_BUY) price = Ask; else price = Bid;	       
          if(ECN)
            ticket = OrderSend(Symbol(), mode, Lots, price, 3*pips2points, 0, 0, oComment, magic_number, 0, arrow);
          else
            ticket=OrderSend(Symbol(), mode, Lots, price, 3*pips2points, StopLoss, TakeProfit, oComment, magic_number, 0, arrow);
          e = GetLastError();
          TradeIsNotBusy();
          if (e > 0)  check = e;
   } // for OrderSend()
   if(ECN)  {
      Sleep(30000); // wait half a minute for OrderSend()'s to be processed
      for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
         if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && OrderMagicNumber()  == magic_number ) {
            if(TradeIsBusy() < 0) // Trade Busy semaphore 
               return(-1);
            OrderModify(OrderTicket(), OrderOpenPrice(), StopLoss, TakeProfit, 0, arrow);
            e = GetLastError();
            TradeIsNotBusy();
            if (e > 0)  check = e;
         }
      }
   }
   return(check);
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

 