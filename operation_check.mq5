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
  return(INIT_SUCCEEDED);
}

void OnStart()
{
  // double minVolume = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
	// double maxVolume = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
	// double stepVolume = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  // Print("minVolume value: ", minVolume);
  // Print("maxVolume value: ", maxVolume);
  // Print("stepVolume value: ", stepVolume);

  // int digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); // 小数点以下の桁数（精度）
  int digits = Digits(); // 小数点以下の桁数（精度）
  Print("digits: ", digits);

  double point = Point();
  Print("point: ", point);

}
