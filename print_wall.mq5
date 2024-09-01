//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

input double high;
input double low;
input string current_direction_of_breakout;
input string previous_direction_of_breakout;
input ulong expertMagic = 10;

double highOfRange;
double lowOfRange;
string currentDirectionOfBreakout;
string previousDirectionOfBreakout;
bool isInRange;
double comparativeHigh;
double comparativeLow;
datetime lastBarTime;
MqlTradeRequest request;
MqlTradeResult result;


int OnInit()
{
  highOfRange = high;
  lowOfRange = low;
  currentDirectionOfBreakout = current_direction_of_breakout;
  previousDirectionOfBreakout = previous_direction_of_breakout;
  isInRange = true;
  comparativeHigh = 0.0;
  comparativeLow = 0.0;
  lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
  return(INIT_SUCCEEDED);
}


void OnTick()
{
  datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
  if (currentBarTime == lastBarTime) return;
  lastBarTime = currentBarTime;

  ZeroMemory(request);
  ZeroMemory(result);

  if(isInRange){
    if (!is_range_broken()) return;
    if(currentDirectionOfBreakout != "both"){
      find_and_save_turning_point();
      isInRange = false;
    } else {
      isInRange = true;
    }
    return;
  }

  if(!isInRange){
    if(!is_range_confirmed()) return;
    isInRange = true;
    return;
  }
}

bool is_range_broken()
{
  double latest_bar_high = iHigh(Symbol(),Period(), 1);
  double latest_bar_low = iLow(Symbol(),Period(), 1);
  bool is_updated = false;

  if(latest_bar_high > highOfRange && latest_bar_low < lowOfRange){
    // レンジを上下どちらにも更新した場合
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "both";
    comparativeHigh = latest_bar_high;
    comparativeLow = latest_bar_low;
    // この足がレンジになる
    highOfRange = latest_bar_high;
    lowOfRange = latest_bar_low;
    Print("★レンジをどちらにも抜けた");
    Print("★レンジ上限： ", highOfRange);
    Print("★レンジ下限： ", lowOfRange);
  }

  if(is_updated == false && latest_bar_high > highOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "above";
    comparativeHigh = latest_bar_high;
    comparativeLow = latest_bar_low;
  }

  if(is_updated == false && latest_bar_low < lowOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "below";
    comparativeHigh = latest_bar_high;
    comparativeLow = latest_bar_low;
  }

  return is_updated;
}

bool is_range_confirmed()
{
  double latest_bar_high;
  double latest_bar_low;
  bool is_confirmed;
  // 最新の確定した足
  latest_bar_high = iHigh(Symbol(),Period(), 1);
  latest_bar_low = iLow(Symbol(),Period(), 1);

  if(currentDirectionOfBreakout == "above"){
    // 上抜け中の場合

    if(latest_bar_high > comparativeHigh){
      // 高値更新
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      is_confirmed = false;
    } else {
      // 高値が更新されなかった場合

      if (latest_bar_low < comparativeLow) {
        // 安値更新
        highOfRange = comparativeHigh;
        is_confirmed = true;
        Print("★レンジ確定");
        Print("レンジ上限： ", highOfRange);
        Print("レンジ下限（既出）： ", lowOfRange);
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合

    if(latest_bar_low < comparativeLow){
      // 安値更新
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      is_confirmed = false;
    } else {
      // 安値が更新されなかった場合

      if (latest_bar_high > comparativeHigh) {
        // 高値更新
        lowOfRange = comparativeLow;
        is_confirmed = true;
        Print("★レンジ確定");
        Print("レンジ下限： ", lowOfRange);
        Print("レンジ上限（既出）： ", highOfRange);
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "both"){
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！is_range_confirmed: Logic's fucked up!!!");
  }

  return is_confirmed;
}

void find_and_save_turning_point()
{
  if(currentDirectionOfBreakout == "above"){
    lowOfRange = find_last_low();
    Print("★レンジを上に抜けた");
    Print("★レンジ下限： ", lowOfRange);
  } else if(currentDirectionOfBreakout == "below") {
    highOfRange = find_last_high();
    Print("★レンジを下に抜けた");
    Print("★レンジ上限： ", highOfRange);
  } else if(currentDirectionOfBreakout == "both") {
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！find_and_save_turning_point: Logic's fucked up!!!");
  }
}

double find_last_high()
{
  double last_high;
  // ↓レンジブレイクした足
  double high = iHigh(Symbol(),Period(), 1);
  double low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_high > high){
      // 高値更新
      high = previous_bar_high;
      low = previous_bar_low;
      is_found = false;
    } else {
      // 高値が更新されなかった場合

      if (previous_bar_low < low) {
        // 安値更新
        last_high = high;
        is_found = true;
      } else {
        // はらみ足

        // 抱き足の安値を直近安値とする
        lowOfRange = low;
        is_found = true;
      }
    }
  }

  return last_high;
}

double find_last_low()
{
  double last_low;
  // ↓レンジブレイクした足
  double high = iHigh(Symbol(),Period(), 1);
  double low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_low < low){
      // 安値更新
      high = previous_bar_high;
      low = previous_bar_low;
      is_found = false;
    } else {
      // 安値が更新されなかった場合

      if (previous_bar_high > high) {
        // 高値更新
        last_low = low;
        is_found = true;
      } else {
        // はらみ足

        // 抱き足の高値を直近高値とする
        highOfRange = high;
        is_found = true;
      }
    }
  }

  return last_low;
}
