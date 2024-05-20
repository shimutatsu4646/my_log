//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

int OnInit()
{
  int marketType = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXECUTION_MARKET);
  Print("marketType: ", marketType);
  int fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  Print("fillType: ", fillType);
  return(INIT_SUCCEEDED);
}

void OnTick()
{
  Print("woo");
}