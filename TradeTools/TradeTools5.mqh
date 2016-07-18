//+------------------------------------------------------------------+
//|                                                  TradeTools5.mq4 |
//|                                            Copyright 2014 chew-z |
//| Duża refaktoryzacja kodu                                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012-2016 chew-z"
#property link      "Trade tools 2016 chew-z"

input int SL                     = 20;   //StopLoss
input int TP                     = 60;   //TakeProfit
input int TE                     = 06;   //Time Exit

input int minBar = 20; //minimum bar size in pips
input int End_Hour               = 22;

input bool    UseMoneyManagement = false;
input int     NofStrategies      = 1;
input double  dollar_f           = 100.0;
input int     maxContracts       = 1;
input double  maxLots            = 1.0;
input int     MaxRisk            = 200; //Maximum risk in pips
input float   MaxRiskPct         = 1.0; //Maximum risk w %
input bool    isLongAllowed      = true; // Are we allowing Long positions?
input bool    isShortAllowed     = true; // or Short positions?

// Pin-pin
input int  minPeriod             = 5;
input int  maxPeriod             = 20;
input int  Shift                 = 1;
input int  K                     = 4;    // filtr trendu -- K-tego dnia a nie po K dniach

input bool    SendAlerts         = true;
input bool    SendNotifications  = true; // Send iPhone notification to mobile MQL client

input bool ECN = true;
input int  EMA = 60;

int      lookBackDays = 10;
int      Today;
double   L, H;
int counter = 0; //counter of idle ticks in alerts
int      pips2points;
double   pips2dbl;       // Stoploss 15 pips    0.015      0.0150
int      Digits_pips;    // DoubleToStr(dbl/pips2dbl, Digits.pips)
double   dbl2pips;       //

static int     BarTime;
string         AlertText ="";
string         AlertEmailSubject  = "";
/////////////////////////// SIGNALS ////////////////////////////////////
bool isRecentHigh_L() { // Czy rynek w ci¹gu K dni ustanawia³ nowe szczyty?
double Hj, Hi;
int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
      Hj = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,f_lookBackDays(),iDay+1));
      Hi = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH, K,iDay+1));
      if (Hi >= Hj)
         return(true);
return(false);
}

bool isRecentLow_S() { // Czy rynek w ci¹gu K dni ustanawia³ ustanawia³ nowe do³ki?
double Lj, Lo;
int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
      Lj = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,f_lookBackDays(),iDay+1));
      Lo = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, K,iDay+1));
      if (Lo <= Lj)
         return(true);
return(false);
}

bool isPullback_L1() { // Czy rynek cofn¹³ siê od H?
double Lj, Lo, Cl;
int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
      Lj = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, f_lookBackDays(),iDay+1));
      Lo = iLow(NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW, K,iDay+1));
      Cl = iLow(NULL, PERIOD_D1,iDay+1);
      if (Cl > Lj && Close[1] <= Lo) //  Jeœli ostatnie zamkniêcie/(ew. do³ek) poni¿ej krótkoterminowego do³ka ale powy¿ej L
         return(true);
return(false);
}

bool isPullback_S1() { // Czy rynek cofn¹³ siê od L?
double Hj, Hi, Cl;
int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
      Hj = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,f_lookBackDays(),iDay+1));
      Hi = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH, K,iDay+1));
      Cl = iHigh(NULL, PERIOD_D1,iDay+1);
      if (Cl < Hj && Close[1] >= Hi) //  Jeœli ostatnie zamkniêcie/(ew. szczyt) powy¿ej krótkoterminowego szczytu ale poni¿ej H
         return(true);
return(false);
}
double f_lookBackDays() {
   double TodayVol, YestVol;
   double deltaVol = 0.0;

   int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false) + 1;
// aktualne StdDev
   TodayVol = iStdDev(NULL, PERIOD_D1, EMA, 0, MODE_EMA, PRICE_CLOSE, iDay);
// StdDev cofniete o Shift dni (!!) niezale¿nie od timeframe wykresu
   YestVol = iStdDev(NULL, PERIOD_D1, EMA, 0, MODE_EMA, PRICE_CLOSE, iDay + Shift);
      if(YestVol!=0)
      deltaVol = MathLog( TodayVol  / YestVol) ;        //
      lookBackDays = maxPeriod / 2;
      if(deltaVol > 0.028)
         lookBackDays = maxPeriod;
      if(deltaVol < -0.028)
         lookBackDays = minPeriod;
      return(lookBackDays);
}

double f_initialStop_5() {
   return( iATR(NULL,PERIOD_D1,10,0) );
}
/** v6.0
 * A pin bar is a hammer like formation where the body of the candle
 * is at one extreme of the entire candle and the wick making up the
 * remainder of the candle. The body of the candle should be no more
 * than 1/3 of the entire candle, with the remaining wick taking up
 * no more than 2/3 of the remainder of the body.
 * https://gist.github.com/currencysecrets/5942989
 */
double PinBar2(int minimumBar) {
  double o=Open[1], c=Close[1];
  double h=High[1], l=Low[1];
  double b = MathAbs( o - c );
  if ((h-l) < minimumBar*pips2dbl) //ignoruj śmieci
    return(0.0);
  double wup = h - MathMax(o, c), wdn = MathMin(o, c) - l;
  if (wup >= 2.0*b && wdn <= b) //długi górny wąs - sygnał na krótką
        return (-wup/b);
  if (wdn >= 2.0*b && wup <= b) //długi dolny wąs - sygnał na długą
        return (wdn/b);
return (0.0);
}
////////////////////////////////////////////////////////////////////////////
int MotherBar(int k) { //find largest bar within last K day bars
int MoBar = k;
  for(int i = k; i > 1; i--)
    if (BarSize(i) < BarSize(i-1))
      MoBar = i-1;

return (MoBar);
}
/*
int MotherBarD(int k) { //find largest bar within last K bars
int MoBar = k;
  for(int i = k; i > 1; i--)
    if (BarSizeD(i) < BarSizeD(i-1))
      MoBar = i-1;

return (MoBar);
}
*/
int MotherBarD(int Range) { //find largest bar within last K bars
double BarSizeArr[];
int c = ArrayResize(BarSizeArr, Range+3); //array with some extra space
Print("c = ", c, " range = ", Range);
int cnt = 0;
c -= 1;
while(c > 0) {
        BarSizeArr[c] = BarSizeD(c);
        if (TimeDayOfWeek( iTime(NULL, PERIOD_D1, c) ) == 0) {
            Print( "MotherBar - skipping Sunday inside bar ", TimeDay( iTime(NULL, PERIOD_D1, c) ) );
            BarSizeArr[c] = 0.0;
            if (c <= Range) //if skipping Sun extend Range
                cnt += 1;
        }
        Print(TimeDay( iTime(NULL, PERIOD_D1, c)), " c = ", c, " bar size = ", BarSizeArr[c]*dbl2pips);
        c -= 1;
}
    int MoBar = ArrayMaximum(BarSizeArr, Range + cnt, 1);
    //Print( "MotherBar: ", TimeDay( iTime(NULL, PERIOD_D1, MoBar) ) );
    return (MoBar);
}

bool isInsideBar(int k) { // is largest (k) bar completely overshadowing inside bar?
  int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
  if (iLow(NULL, PERIOD_D1, iDay+k) < iLow(NULL, PERIOD_D1, iDay+1)
    && iHigh(NULL, PERIOD_D1, iDay+k) > iHigh(NULL, PERIOD_D1, iDay+1))
    return true;

return false;
}

/*
bool isInsideBarD(int k) { // is largest (k) bar completely overshadowing inside bar?
  int i = 1;
  if (TimeDayOfWeek( iTime(NULL, PERIOD_D1, i) ) == 0) {
    Print( "isInsideBar - skipping Sunday inside bar ", TimeDay( iTime(NULL, PERIOD_D1, i) ) );
    i += 1;
  }
  if (Low[k] < Low[i] && High[k] > High[i]) {
    Print(TimeDay( iTime(NULL, PERIOD_D1, i)), " is Inside bar of ",  TimeDay(iTime(NULL, PERIOD_D1, k)));
    return true;
  }

return false;
*/
int InsideBarD(int k) { // largest (k) bar completely overshadowing inside bar?
  int i = 1;
  if (TimeDayOfWeek( iTime(NULL, PERIOD_D1, i) ) == 0) {
    Print( "InsideBarD - skipping Sunday inside bar ", TimeDay( iTime(NULL, PERIOD_D1, i) ) );
    i += 1;
  }
  if (Low[k] < Low[i] && High[k] > High[i]) {
    Print(TimeDay( iTime(NULL, PERIOD_D1, i)), "/", TimeMonth( iTime(NULL, PERIOD_D1, i)),
        " is Inside bar of ", TimeDay(iTime(NULL, PERIOD_D1, k)), "/" ,TimeMonth(iTime(NULL, PERIOD_D1, k)));
    return i;
  }

return 0;
}

double BarSize(int i) {
    int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
    double l = iLow(NULL, PERIOD_D1, iDay+i);
    double h = iHigh(NULL, PERIOD_D1, iDay+i);

return (h-l);
}

double BarSizeD(int i) {
    double l = Low[i];
    double h = High[i];

return (h-l);
}

double BodySize(int i) {
    int iDay = iBarShift(NULL, PERIOD_D1, Time[0], false);
    double c = iClose(NULL, PERIOD_D1, iDay+i);
    double o = iOpen(NULL, PERIOD_D1, iDay+i);

return MathAbs(c-o);
}

/*
bool isBarSignificant() { // is last bar large enough to validate the signal?
    int i = 1;
    if (TimeDayOfWeek( iTime(NULL, PERIOD_D1, i) ) == 0) {
        Print( "isBarSignificant - skipping Sunday inside bar ", TimeDay( iTime(NULL, PERIOD_D1, i) ) );
        i += 1;
    }
    if (BarSizeD(i) > minBar*pips2dbl)
        return true;
return false;
}
*/

bool isBarSignificant(int i) { // is last bar large enough to validate the signal?
    if (BarSizeD(i) > minBar*pips2dbl)
        return true;
return false;
}

double f_TrueATR(int Range, int iDay) { //weź trzy ostatnie sesje odrzucając niedziele
    double sum = 0.0;
    int loop = 0;
    int i = iDay + 1; //iD should first
    while(loop < Range ) {
        if (TimeDayOfWeek( iTime(NULL, PERIOD_D1, i) ) == 0) {
            Print( "skipping Sunday ", TimeDay( iTime(NULL, PERIOD_D1, i) ) );
            i += 1;
        } else {
            sum += (iHigh(NULL, PERIOD_D1, i) - iLow(NULL, PERIOD_D1, i));
            i += 1;
            loop += 1;
        }
    }
    double true_ATR = NormalizeDouble(1.0/Range * sum, Digits);
    return(true_ATR);
}

double pipsValue(string S) {
// returns dollar value of one pips (for FX) or (for CFD) ..
// works for some instrumenst only, requires some improvements
    // CFD
    if ( S == "FJP225")
        return ( Point * 1000.00/MarketInfo("USDJPY", MODE_ASK) );
    if ( S == "FUS500")
        return ( 100.0 * Point );
    if ( S == "FUS100")
        return ( 40.00 * Point );
    if ( S == "FDE30")
        return ( Point * 10.00 * MarketInfo("EURUSD", MODE_ASK) );
    if ( S == "FGB100")
        return ( Point * 10.00 * MarketInfo("GBPUSD", MODE_ASK) );
    if ( S == "FEU50")
        return ( Point * 20.00 * MarketInfo("EURUSD", MODE_ASK) );
    if ( S == "FCN40")
        return ( Point / MarketInfo("USDHKD", MODE_ASK) );
    if ( S == "FHK45")
        return ( Point / MarketInfo("USDHKD", MODE_ASK) );
    if ( S == "FTNOTE10")
        return ( 1000.00  * Point); // Should be 10 000.00 but ..
    if ( S == "FUSD")
        return ( 1000.00  * Point );
    if ( S == "FBUND10")
        return ( Point * 500.00 * MarketInfo("EURUSD", MODE_ASK) );
    if ( S == "FEUBANKS")
        return ( Point * 1000.00 * MarketInfo("EURUSD", MODE_ASK) );
    if ( S == "FOAT10")
        return ( Point * 500.00 * MarketInfo("EURUSD", MODE_ASK) );
    if ( S == "FBTP10")
        return ( Point * 500.00 * MarketInfo("EURUSD", MODE_ASK) );
    if ( S == "FOIL")
        return ( 1000.00  * Point );
    if ( S == "FCOPPER")
        return ( 25000.00  * Point ); // ??
    if ( S == "FCORN")
        return ( 150.00 * Point );
    if ( S == "FWHEAT")
        return ( 100.00 * Point );
    if ( S == "FSOYBEAN")
        return ( 50.00 * Point );
    if ( S == "FCOTTON")
        return ( 1000.00  * Point );
    if ( S == "FSUGAR")
        return ( 5600.00 * Point );
    if ( S == "FRICE")
        return ( 5000.00 * Point );
    if ( S == "FCOCOA")
        return ( 20.00 * Point );
    if ( S == "FGOLD")
        return ( 50.00 * Point);
    if ( S == "US500")
        return ( 50.0 * Point );
    if ( S == "JPN225")
        return ( Point * 1000.00/MarketInfo("USDJPY", MODE_ASK) );
    if ( S == "USD_I")
        return ( 1000.00  * Point );
    if ( S == "TNOTE")
        return ( 20000.00  * Point ); // Should be 2000.00 but Digits=3 and double2pips is wrong
    if ( S == "EURBUND")
        return ( Point * 1000.00 * MarketInfo("EURUSD", MODE_ASK) );
    if ( S == "WTI")
        return ( 1000.00  * Point );
    if ( S == "COPPER")
        return ( 200.00  * Point );
    // FX
    string S1 = StringSubstr( S, 0, 3 );
    string S2 = StringSubstr( S, 3, 3 );
    if ( S2 == "USD")
        return ( 10.0 );
    if ( S2 == "JPY" )
        return ( 1000.00/MarketInfo("USDJPY", MODE_ASK) );
    if ( S2 == "CAD")
        return ( 10.0/MarketInfo( "USDCAD", MODE_ASK) );
    // and return 0 for all undefinied cases
    return (0.0);
}

double pipsValuePLN(string symbol) {
// There is a catch. During testing MarketInfo( "USDPLN", MODE_ASK) is always 0;
//    if( IsTesting() ) {
//        //Print("I am testing now");
//        double lastprice = iClose("USDPLN", Period(), iBarShift( "USDPLN", PERIOD_D1, Time[0]));
//        return ( pipsValue(symbol) * lastprice );
//    }
    return (pipsValue(symbol) * MarketInfo( "USDPLN", MODE_ASK));
}

double f_riskUSD(string S) {
    // computes risk in $ for MaxRiskPct (in % of lot value)
    // S is a Symbol()
    string S1, S2;
    S1 = StringSubstr(S, 0, 3 ); S2 = StringSubstr(S, 3, 3 );
    double lotsize = MarketInfo(S, MODE_LOTSIZE);
    double price = MarketInfo(S, MODE_ASK);
    double riskUSD = 0.0;

    if ( S1 == "USD" )
        riskUSD = (MaxRiskPct/100.0) * lotsize;
    if ( S2 == "USD" )
        riskUSD = (MaxRiskPct/100.0) * lotsize * price;
    if ( S == "FJP225")
        riskUSD = (MaxRiskPct/100.0) * lotsize * price / MarketInfo("USDJPY", MODE_ASK);
    if ( S == "FUS500")
        riskUSD = (MaxRiskPct/100.0) * lotsize * price;
    if ( S == "FTNOTE10")
        riskUSD = (MaxRiskPct/100.0) * lotsize * price;
    if ( S == "FDE30")
        riskUSD = (MaxRiskPct/100.0) * lotsize * price * MarketInfo("EURUSD", MODE_ASK);
    if ( S == "FGB100")
        riskUSD = (MaxRiskPct/100.0) * lotsize * price * MarketInfo("GBPUSD", MODE_ASK);
    // ... etc. 
    riskUSD = NormalizeDouble(riskUSD, 0);
    return (riskUSD);
}

double f_pointUSD(string S) {
    // Computes point value in USD
    // S is a Symbol()
    string S1, S2;
    S1 = StringSubstr(S, 0, 3 ); S2 = StringSubstr(S, 3, 3 );
    double lotsize = MarketInfo(S, MODE_LOTSIZE);
    double price = MarketInfo(S, MODE_ASK);
    double pointUSD = 0.0;

    if ( S2 == "USD" )
        pointUSD = lotsize * Point;
    if ( S1 == "USD" )
        pointUSD = lotsize * Point / price;
    if ( S == "FJP225")
        pointUSD = lotsize * Point / MarketInfo("USDJPY", MODE_ASK);
    if ( S == "FUS500")
        pointUSD = lotsize * Point;
    if ( S == "FTNOTE10")
        pointUSD = lotsize * Point;
    if ( S == "FDE30")
        pointUSD = lotsize * Point * MarketInfo("EURUSD", MODE_ASK);
    if ( S == "FGB100")
        pointUSD = lotsize * Point * MarketInfo("GBPUSD", MODE_ASK);
    // ... etc.
    pointUSD = NormalizeDouble(pointUSD, 2);
    return (pointUSD);
}
/////////////////////////// ORDERS /////////////////////////////////////////
int f_SendOrders_OnLimit(int mode, int contract, double price, double Lots, double StopLoss, double TakeProfit, int magic_number, datetime expiration, string oComment) {
int e, check = 0;
int ticket = 0;
color arrow = Red;
   if (mode == OP_BUYLIMIT || mode == OP_BUYSTOP) arrow = Green;

   for(int cnt=contract; cnt>=1; cnt--) {
          if(TradeIsBusy() < 0) // Trade Busy semaphore
                     return(-1);
          RefreshRates(); // dodatkowe refresh
         ticket = OrderSend(Symbol(), mode, Lots, price, 3*pips2points, StopLoss, TakeProfit, oComment, magic_number, expiration, arrow);
         e = GetLastError();
         TradeIsNotBusy();
         if (e > 0)  check = e;
   } // for OrderSend()
return(check);
}
int f_SendOrders(int mode, int contract, double Lots, double StopLoss, double TakeProfit, int magic_number, string oComment) {
int e, check = 0;
int ticket = 0;
double price = 0.0;
color arrow = Red;
   if (mode == OP_BUY) arrow = Green;
   for(int cnt=contract; cnt>=1; cnt--) {
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
            check = OrderModify(OrderTicket(), OrderOpenPrice(), StopLoss, TakeProfit, 0, arrow);
            e = GetLastError();
            TradeIsNotBusy();
            if (e > 0)  check = e;
         }
      }
   }
   return(check);
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

int f_OrdersTotal(int magic_number, int& ticketArray[]) {
//'ticket'alternative to f_Orders_Total() - returns number of open orders and their tickets to array
  int kounter = -1; //return -1 if no active orders
  int ticket = 0;
  for(int cnt=OrdersTotal()-1;cnt>=0;cnt--) {
    if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position
                                                    && OrderSymbol() == Symbol()                 // check for symbol
                                                    && (OrderMagicNumber()  == magic_number) ) // my magic number
    {
      ticket = OrderTicket();
      kounter++;
      ticketArray[kounter] = ticket;
    } //Print("Order ticket #", ticket);
  }
  return(kounter);
}

int f_LimitOrders(int magic_number, int& ticketArray[]) {
// returns number of limit orders and their tickets to array
  int kounter = -1; //return -1 if no active orders
  int ticket = 0;
  for(int cnt=OrdersTotal()-1;cnt>=0;cnt--) {
    if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() > OP_SELL                    // check for opened position
                                                    && OrderSymbol() == Symbol()                 // check for symbol
                                                    && (OrderMagicNumber()  == magic_number) ) // my magic number
    {
      ticket = OrderTicket();
      kounter++;
      ticketArray[kounter] = ticket;
    } //Print("Order ticket #", ticket);
  }
  return(kounter);
}
/////////////////////////// POMOCNICZE /////////////////////////////////
void f_SendAlerts(string Text) {
   if (SendAlerts) {
      if (AlertEmailSubject > "") SendMail(AlertEmailSubject, Text);
      if(SendNotifications) SendNotification(Text);
      Alert(Text);
      //Print(Text);
   }
}

int f_hours_diff(datetime day1, datetime day2) {
    int diff = MathFloor((day2 - day1)/3600.0);
    return(diff);
}

/* TimeLocal() != TimeCurrent() and the shift changes with DST
So it helps to check for offset between server time and terminal time.
In hours, screw Sri Lanka, Nepal and other exotic places.
*/
int f_TimeOffset() {
datetime dl = TimeLocal();
datetime ds = TimeCurrent();

  if ( dl  >  ds )
    return(MathFloor( (dl-ds)/3600.0) );
  else
    return(MathCeil( (dl-ds)/3600.0) );
}
/* TimeLocal & TimeCurrent
*/

int f_TimeSlip() {
datetime dl = TimeLocal();
datetime ds = TimeCurrent();

int ts = (dl-ds) - (f_TimeOffset() * 3600);

    return(ts);
}

bool NewBar()  {
   if(BarTime != Time[0]) {
      BarTime = Time[0];
      return(true);
   } else {
      return(false);
   }
}

bool NewDay() {  // This is depreciated, use NewDay2(). Kept for compatibility with older code
   if(Today!=DayOfWeek()) {
      Today=DayOfWeek();
      return(true);
   }
   return(false);
}

bool NewDay2() { //Use server time and go around wintertime bug
//During wintertime somehow DayOfWeek changes at 23:00 not 00:00
//also on Sundays trading starts at 23:00 (or 22:00) (which is probably 00:00 Monday somewhere)
//forming lousy misleading D1 candles.
//This is a trick to go around it. Not perfect but...
   datetime dt = TimeCurrent();
   if(Today!=TimeDayOfWeek(dt) && TimeHour(dt) < End_Hour ) { //&& TimeDayOfWeek(dt)!=0
      Today=TimeDayOfWeek(dt);
      return(true);
   }
   return(false);
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

string getDeinitReasonText(int reasonCode)  {
   string text="";
   switch(reasonCode)
     {
      case REASON_PROGRAM:
        text="EA terminated its operation";break;
      case REASON_REMOVE:
         text="Indicator removed from chart";break;
      case REASON_RECOMPILE:
         text="Indicator recompiled";break;
      case REASON_CHARTCHANGE:
         text="Symbol or timeframe was changed";break;
      case REASON_CHARTCLOSE:
         text="Chart closed";break;
      case REASON_PARAMETERS:
         text="Input parameter has been changed";break;
      case REASON_ACCOUNT:
         text="Account was changed";break;
      case REASON_TEMPLATE:
         text="New template applied to chart";break;
      case REASON_INITFAILED:
         text="OnInit() returned a nonzero value";break;
      case REASON_CLOSE:
         text="Terminal has been closed";break;
      default:text="Another reason";
     }
   return text;
}
