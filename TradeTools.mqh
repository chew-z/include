//+------------------------------------------------------------------+
//|                                                   TradeTools.mq4 |
//|                                            Copyright 2012 chew-z |
//| Ma�a refaktoryzacja kodu                                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012, 2014 chew-z"
#property link      "Trade tools 2014 chew-z"
extern bool ECN = true;
extern int  EMA = 60;

extern bool    UseMoneyManagement = false;
extern int     NofStrategies      = 1;
extern double  dollar_f           = 1.0;
extern double  maxLots            = 0.10;
extern int     maxContracts       = 1;

extern int  minPeriod             = 5;
extern int  maxPeriod             = 20;
extern int Shift                  = 1;
extern int K                      = 5;              // filtr trendu -- K-tego dnia a nie po K dniach

extern int SL                     = 20;
extern int TP                     = 60;

extern int    rangeX              = 1500; // in trendline indicator range of backsearch for peak or valley
extern int    blindRange          = 72;   // ignore recently formed tops/bottoms

extern bool    SendAlerts         = true;
extern bool    SendNotifications  = true;        // Send iPhone notification to mobile MQL client
extern string  AlertEmailSubject  = "MQL Alert"; // Empty subject = don't send emails

int      lookBackDays = 10;
int      Today;
double   L, H;
int counter = 0; //counter of idle ticks in alerts
int      pips2points;
double   pips2dbl;       // Stoploss 15 pips    0.015      0.0150
int      Digits_pips;    // DoubleToStr(dbl/pips2dbl, Digits.pips)
/////////////////////////// SIGNALS ////////////////////////////////////
bool isTrending_L() { // Czy �rednia szybka powy�ej wolnej?
int i;
double M;
int sig = 0;
   for (i = K; i>-1; i--) {   //K-tego dnia a nie po K dniach
      M = iMA(NULL, PERIOD_D1, maxPeriod, 0, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i);
      if (iMA(NULL, PERIOD_D1, minPeriod, 0, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i) > M)
         sig++;
   }
   if(sig < K)
      return(false);
   else 
      return(true);
}
bool isTrending_S1(int j) { // Czy �rednia szybka poni�ej wolnej?
int i;
double M;
int sig = 0;
   for (i = K; i>-1; i--) {  //K-tego dnia a nie po K dniach
      M = iMA(NULL, PERIOD_D1, maxPeriod, j, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i);
      if (iMA(NULL, PERIOD_D1, minPeriod, j, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i) < M)
         sig++;
   }
   if(sig < K)
      return(false);
   else 
      return(true);
}
bool isTrending_L1(int j) { // Czy �rednia szybka powy�ej wolnej?
int i;
double M;
int sig = 0;
   for (i = K; i>-1; i--) {   //K-tego dnia a nie po K dniach
      M = iMA(NULL, PERIOD_D1, maxPeriod, j, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i);
      if (iMA(NULL, PERIOD_D1, minPeriod, j, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i) > M)
         sig++;
   }
   if(sig < K)
      return(false);
   else 
      return(true);
}
bool isTrending_S() { // Czy �rednia szybka poni�ej wolnej?
int i;
double M;
int sig = 0;
   for (i = K; i>-1; i--) {  //K-tego dnia a nie po K dniach
      M = iMA(NULL, PERIOD_D1, maxPeriod, 0, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i);
      if (iMA(NULL, PERIOD_D1, minPeriod, 0, MODE_EMA, PRICE_CLOSE, iBarShift(NULL,PERIOD_D1,Time[Shift],false)+i) < M)
         sig++;
   }
   if(sig < K)
      return(false);
   else 
      return(true);
}
bool isRecentHigh_L() { // Czy rynek w ci�gu K dni ustanawia� nowe szczyty?
double Hj, Hi;
      Hj = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,f_lookBackDays(),1));
      Hi = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH, K,1));
      if (Hi >= Hj)
         return(true);
return(false);
}
bool isPullback_L() { // Czy rynek cofn�� si� od H?
double Lj, Lo, Cl;
      Lj = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, f_lookBackDays(), 1));
      Lo = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, K, 1));
      Cl = iLow(NULL, PERIOD_D1, 1);
      if (Cl > Lj && Cl <= Lo) //  Je�li ostatnie zamkni�cie/(ew. do�ek) poni�ej kr�tkoterminowego do�ka ale powy�ej L
         return(true);
return(false);
}
bool isPullback_L1() { // Czy rynek cofn�� si� od H?
double Lj, Lo, Cl;
      Lj = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, f_lookBackDays(), 1));
      Lo = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, K, 1));
      Cl = iLow(NULL, PERIOD_D1, 1);
      if (Cl > Lj && Close[1] <= Lo) //  Je�li ostatnie zamkni�cie/(ew. do�ek) poni�ej kr�tkoterminowego do�ka ale powy�ej L
         return(true);
return(false);
}
bool isRecentLow_S() { // Czy rynek w ci�gu K dni ustanawia� ustanawia� nowe do�ki?
double Lj, Lo;
      Lj = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,f_lookBackDays(), 1));
      Lo = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, K, 1));
      if (Lo <= Lj)
         return(true);
return(false);
}
bool isPullback_S() { // Czy rynek cofn�� si� od L?
double Hj, Hi, Cl;
      Hj = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,f_lookBackDays(),1));
      Hi = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH, K, 1));
      Cl = iHigh(NULL, PERIOD_D1, 1);
      if (Cl < Hj && Cl >= Hi) //  Je�li ostatnie zamkni�cie/(ew. szczyt) powy�ej kr�tkoterminowego szczytu ale poni�ej H
         return(true);
return(false);
}
bool isPullback_S1() { // Czy rynek cofn�� si� od L?
double Hj, Hi, Cl;
      Hj = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,f_lookBackDays(),1));
      Hi = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH, K, 1));
      Cl = iHigh(NULL, PERIOD_D1, 1);
      if (Cl < Hj && Close[1] >= Hi) //  Je�li ostatnie zamkni�cie/(ew. szczyt) powy�ej kr�tkoterminowego szczytu ale poni�ej H
         return(true);
return(false);
}
bool isBreakout_H() {
   if ( Ask > H && ((H - Open[1]  > 20 * pips2dbl) ) )
      return(true);
   return(false);

}
bool isBreakout_L() {
   if ( Bid < L && ((Open[1] - L  > 20 * pips2dbl)  ) )
      return(true);
   return(false);

}
/////////////////////////// STOPS & TAKE PROFITS ///////////////////////
double f_initialStop_L() {
   return( Ask - 1.0 * iATR(NULL,PERIOD_D1,10,0) );   
}
double f_initialStop_S() {
   return(Bid + 1.0 * iATR(NULL,PERIOD_D1,10,0));   
}
double f_trailingStop_L() {
   return( iClose(NULL, PERIOD_D1, iLowest(NULL,PERIOD_D1,MODE_CLOSE, K, 1))  );   
}
double f_trailingStop_S() {
   return( iClose(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_CLOSE, K, 1)) );   
}
double f_tp_L() {
   return( Ask + 3.0 * iATR(NULL,PERIOD_D1,10,0) );   // simple 3:1 reward:risk
}
double f_tp_S() {
   return(Bid - 3.0 * iATR(NULL,PERIOD_D1,10,0));   
}
/////////////////////////// EXITS //////////////////////////////////////
bool isExit_L() { // Czy Stochastic sygnalizuje koniec?
double stoch_main1 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_MAIN  ,0);
double stoch_sign1 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_SIGNAL,0);
double stoch_main2 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_MAIN  ,2);
double stoch_sign2 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_SIGNAL,2);
      if (stoch_main1 > 80 && stoch_main2 > stoch_sign2 && stoch_main1 < stoch_sign1  )
         return(true);
      else 
         return(false);
}
bool isExit_S() { // Czy Stochastic sygnalizuje koniec?
double stoch_main1 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_MAIN  ,0);
double stoch_sign1 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_SIGNAL,0);
double stoch_main2 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_MAIN  ,2);
double stoch_sign2 = iStochastic(NULL,PERIOD_D1,14,3,3,MODE_EMA,0,MODE_SIGNAL,2);
      if (stoch_main1 < 20 && stoch_main2 < stoch_sign2 && stoch_main1 > stoch_sign1 )
         return(true);
      else 
         return(false);
}
bool isExit_L1() { // Czy �rednia szybka poni�ej wolnej?
      if (iMA(NULL, PERIOD_D1, minPeriod, 0, MODE_EMA, PRICE_CLOSE, 1) < iMA(NULL, PERIOD_D1, maxPeriod, 0, MODE_EMA, PRICE_CLOSE, 1))
         return(true);
      else 
         return(false);
}
bool isExit_S1() { // Czy �rednia szybka powy�ej wolnej?
      if (iMA(NULL, PERIOD_D1, minPeriod, 0, MODE_EMA, PRICE_CLOSE, 1) > iMA(NULL, PERIOD_D1, maxPeriod, 0, MODE_EMA, PRICE_CLOSE, 1))
         return(true);
      else 
         return(false);
}
/////////////////////////// MONEY MANAGEMENT ///////////////////////////
double f_Money_Management() {
   double c = 1;
        if (UseMoneyManagement) {
            c = MathFloor(( AccountBalance()/ NofStrategies) / dollar_f); //
            if (c > maxContracts)  c = maxContracts;
        } else 
            c = 1;      
   return(c);
}
/////////////////////////// POMOCNICZE /////////////////////////////////
int f_OrdersTotal(int magic_number) {
   int kounter = 0;
   int cnt = 0;
   for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                  // check for opened position 
                                                      && OrderSymbol() == Symbol()               // check for symbol
                                                      && (OrderMagicNumber()  == magic_number) ) // my magic number                                                          
         kounter++;
   }
   return(kounter);
}

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

double f_lookBackDays() {
   double TodayVol, YestVol;
   double deltaVol = 0.0;

   int iDay = iBarShift(NULL, PERIOD_D1, Time[0],false) + 1;
// Pierwszy wskaznik to aktualne StdDev
   TodayVol = iStdDev(NULL, PERIOD_D1, EMA, 0, MODE_EMA, PRICE_CLOSE, iDay);
// Drugi wska�nik to StdDev cofni�te o Shift dni (!!) niezale�nie od timeframe wykresu   
   YestVol = iStdDev(NULL, PERIOD_D1, EMA, 0, MODE_EMA, PRICE_CLOSE, iDay + Shift);
      if(YestVol!=0)
      deltaVol = MathLog(TodayVol  / YestVol) ;        // 
      lookBackDays = maxPeriod / 2;
      if(deltaVol > 0.028)
         lookBackDays = maxPeriod;
      if(deltaVol < -0.028)
         lookBackDays = minPeriod;
      return(lookBackDays);
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

bool NewDay() {
   if(Today!=DayOfWeek()) {
      Today=DayOfWeek();
      return(true);
   }
   return(false);
} 

string getDeinitReasonText(int reasonCode)
  {
   string text="";
//---
   switch(reasonCode)
     {
      case REASON_ACCOUNT:
         text="Account was changed";break;
      case REASON_CHARTCHANGE:
         text="Symbol or timeframe was changed";break;
      case REASON_CHARTCLOSE:
         text="Chart closed";break;
      case REASON_PARAMETERS:
         text="Input parameter has been changed";break;
      case REASON_RECOMPILE:
         text="Indicator recompiled";break;
      case REASON_REMOVE:
         text="Indicator removed from chart";break;
      case REASON_CLOSE:
         text="Terminal has been closed";break;         
      case REASON_TEMPLATE:
         text="New template applied to chart";break;
      default:text="Another reason";
     }
//---
   return text;
  }
//_______________ Peaks and Valleys_______________________________