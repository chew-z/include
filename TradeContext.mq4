/////////////////////////////////////////////////////////////////////////////////
// int TradeIsBusy( int MaxWaiting_sec = 30 )
//
// The function replaces the TradeIsBusy value 0 with 1.
// If TradeIsBusy = 1 at the moment of launch, the function waits until TradeIsBusy is 0,
// and then replaces.
// If there is no global variable TradeIsBusy, the function creates it.
// Return codes:
//  1 - successfully completed. The global variable TradeIsBusy was assigned with value 1
// -1 - TradeIsBusy = 1 at the moment of launch of the function, the waiting was interrupted by the user
//      (the expert was removed from the chart, the terminal was closed, the chart period and/or symbol
//      was changed, etc.)
// -2 - TradeIsBusy = 1 at the moment of launch of the function, the waiting limit was exceeded
//      (MaxWaiting_sec)
/////////////////////////////////////////////////////////////////////////////////
int TradeIsBusy( uint MaxWaiting_sec = 60 )
  {
    // at testing, there is no resaon to divide the trade context - just terminate
    // the function
    if(IsTesting())
        return(1);
    //+------------------------------------------------------------------+
    // check whether it's the "end of the forex day"
    // MM brokers tend to blackout trade at midnight server time
    //+------------------------------------------------------------------+
    datetime dt = TimeCurrent();
    if (ECN != true && TimeHour(dt) == 0 ) {
        while( TimeMinute(dt) < 2 ) {
            Print("Waiting out MM blackout at ", TimeHour(dt), ":", TimeMinute(dt));
            Sleep( 5000 ); // sleep for five seconds
            dt = TimeCurrent();
        }
    }
    //+------------------------------------------------------------------+
    int _GetLastError = 0, StartWaitingTime = GetTickCount();
    //+------------------------------------------------------------------+
    //| Check whether a global variable exists and, if not, create it    |
    //+------------------------------------------------------------------+
    while(true)
      {
        // if the expert was terminated by the user, stop operation
        if(IsStopped())
          {
            Print("The expert was terminated by the user!");
            return(-1);
          }
        // if the waiting time exceeds that specified in the variable
        // MaxWaiting_sec, stop operation, as well
        if(GetTickCount() - StartWaitingTime > MaxWaiting_sec * 1000)
          {
            Print("Waiting time (" + MaxWaiting_sec + " sec) exceeded!");
            return(-2);
          }
        // check whether the global variable exists
        // if it does, leave the loop and go to the block of changing
        // TradeIsBusy value
        if(GlobalVariableCheck( "TradeIsBusy" ))
            break;
        else
        // if the GlobalVariableCheck returns FALSE, it means that it does not exist or
        // an error has occurred during checking
          {
            _GetLastError = GetLastError();
            // if it is still an error, display information, wait for 0.1 second, and
            // restart checking
            if(_GetLastError != 0)
             {
              Print("TradeIsBusy()-GlobalVariableCheck(\"TradeIsBusy\")-Error #",
                    _GetLastError );
              Sleep(100);
              continue;
             }
          }
        // if there is no error, it means that there is just no global variable, try to create
        // it
        // if the GlobalVariableSet > 0, it means that the global variable has been successfully created.
        // Leave the function
        if(GlobalVariableSet( "TradeIsBusy", 1.0 ) > 0 )
            return(1);
        else
        // if the GlobalVariableSet has returned a value <= 0, it means that an error
        // occurred at creation of the variable
         {
          _GetLastError = GetLastError();
          // display information, wait for 0.1 second, and try again
          if(_GetLastError != 0)
            {
              Print("TradeIsBusy()-GlobalVariableSet(\"TradeIsBusy\",0.0 )-Error #",
                    _GetLastError );
              Sleep(100);
              continue;
            }
         }
      }
    //+----------------------------------------------------------------------------------+
    //| If the function execution has reached this point, it means that global variable  |
    //| variable exists.                                                                 |
    //| Wait until the TradeIsBusy becomes = 0 and change the value of TradeIsBusy for 1 |
    //+----------------------------------------------------------------------------------+
    while(true)
     {
     // if the expert was terminated by the user, stop operation
     if(IsStopped())
       {
         Print("The expert was terminated by the user!");
         return(-1);
       }
     // if the waiting time exceeds that specified in the variable
     // MaxWaiting_sec, stop operation, as well
     if(GetTickCount() - StartWaitingTime > MaxWaiting_sec * 1000)
       {
         Print("The waiting time (" + MaxWaiting_sec + " sec) exceeded!");
         return(-2);
       }
     // try to change the value of the TradeIsBusy from 0 to 1
     // if succeed, leave the function returning 1 ("successfully completed")
     if(GlobalVariableSetOnCondition( "TradeIsBusy", 1.0, 0.0 ))
         return(1);
     else
     // if not, 2 reasons for it are possible: TradeIsBusy = 1 (then one has to wait), or

     // an error occurred (this is what we will check)
      {
      _GetLastError = GetLastError();
      // if it is still an error, display information and try again
      if(_GetLastError != 0)
      {
   Print("TradeIsBusy()-GlobalVariableSetOnCondition(\"TradeIsBusy\",1.0,0.0 )-Error #",
         _GetLastError );
       continue;
      }
     }
     //if there is no error, it means that TradeIsBusy = 1 (another expert is trading), then display
     // information and wait...
     Comment("Wait until another expert finishes trading...");
     Sleep(1000);
     Comment("");
    }
    return(0);
  }

/////////////////////////////////////////////////////////////////////////////////
// void TradeIsNotBusy()
//
// The function sets the value of the global variable TradeIsBusy = 0.
// If the TradeIsBusy does not exist, the function creates it.
/////////////////////////////////////////////////////////////////////////////////
int TradeIsNotBusy()
  {
    int _GetLastError;
    // at testing, there is no sense to divide the trade context - just terminate
    // the function
    if(IsTesting())
      {
        return(0);
      }
    while(true)
      {
        // if the expert was terminated by the user
        if(IsStopped())
          {
            Print("The expert was terminated by the user!");
            return(-1);
          }
        // try to set the global variable value = 0 (or create the global
        // variable)
        // if the GlobalVariableSet returns a value > 0, it means that everything
        // has succeeded. Leave the function
        if(GlobalVariableSet( "TradeIsBusy", 0.0 ) > 0)
            return(1);
        else
        // if the GlobalVariableSet returns a value <= 0, this means that an error has occurred.
        // Display information, wait, and try again
         {
         _GetLastError = GetLastError();
         if(_GetLastError != 0 )
           Print("TradeIsNotBusy()-GlobalVariableSet(\"TradeIsBusy\",0.0)-Error #",
                 _GetLastError );
         }
        Sleep(100);
      }
      return(0);
  }