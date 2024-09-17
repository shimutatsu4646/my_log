//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <MyCode/range_line.mqh>
#include <MyCode/long_range_line.mqh>
#include <MyCode/print_error.mqh>
#include <MyCode/asset_management.mqh>
#include <MyCode/handle_order.mqh>
#include <MyCode/turning_point.mqh>
#include <MyCode/long_turning_point.mqh>
#include <MyCode/check_range.mqh>
#include <MyCode/check_long_range.mqh>

// 自分で定義した関数と関数内で定義した変数は、snake_caseにする。

input double high; // 高値
input double low; // 安値
input double longHigh; // 高値
input double longLow; // 安値
// ↓今回、レンジのどちらに抜けたか
input string current_direction_of_breakout; // [current] below=下抜け、avobe=上抜け
// ↓前のレンジ抜けの方向
input string previous_direction_of_breakout; // [previous] below=下抜け、avobe=上抜け
// ↓今回、レンジのどちらに抜けたか（長期時間軸）
input string current_long_direction_of_breakout; // [current] below=下抜け、avobe=上抜け（長期時間軸）
// ↓前のレンジ抜けの方向（長期時間軸）
input string previous_long_direction_of_breakout; // [previous] below=下抜け、avobe=上抜け（長期時間軸）

input ulong expertMagic = 10;
// global variables
double highOfRange; // 高値
double lowOfRange; // 安値
double highOfLongRange; // 高値
double lowOfLongRange; // 安値
string currentDirectionOfBreakout;
string previousDirectionOfBreakout;
string currentLongDirectionOfBreakout;
string previousLongDirectionOfBreakout;
bool isInRange;
bool isInLongRange;
double comparativeHigh; // ブレイク中の比較対象の足の高値
double comparativeLow; // ブレイク中の比較対象の足の安値
double comparativeLongHigh; // ブレイク中の比較対象の足の高値
double comparativeLongLow; // ブレイク中の比較対象の足の安値
datetime lastBarTime; // 最後に確認したバーの時間を格納する変数
datetime lastLongBarTime; // 最後に確認したバーの時間を格納する変数
MqlTradeRequest request;
MqlTradeResult result;
// 市場閉鎖でSendOrderがエラー発生した場合true
// cancel_opposite_orderでのみ発生している前提のロジックとなっている。
bool isMarketClosed;
// int fillType;

int OnInit()
{
  highOfRange = high;
  lowOfRange = low;
  highOfLongRange = longHigh;
  lowOfLongRange = longLow;
  currentDirectionOfBreakout = current_direction_of_breakout;
  previousDirectionOfBreakout = previous_direction_of_breakout;
  currentLongDirectionOfBreakout = current_long_direction_of_breakout;
  previousLongDirectionOfBreakout = previous_long_direction_of_breakout;
  send_order_both_stop_buy_and_stop_sell();
  isInRange = true;
  isInLongRange = true; // inputで受け付ける方が良さそう
  comparativeHigh = 0.0;
  comparativeLow = 0.0;
  comparativeLongHigh = 0.0;
  comparativeLongLow = 0.0;
  lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
  lastLongBarTime = iTime(_Symbol, PERIOD_W1, 0);
  isMarketClosed = false;
  // fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  LineCreate("high");
  LineCreate("low");
  LongLineCreate("high");
  LongLineCreate("low");
  ChartRedraw();
  return(INIT_SUCCEEDED);
}

void OnTick()
{
  // 月足
  // change_long_timebar_data(); ↓内容
  datetime currentLongBarTime = iTime(_Symbol, PERIOD_W1, 0);
  if(currentLongBarTime != lastLongBarTime) {
    lastLongBarTime = currentLongBarTime;
    if(isInLongRange) {
      if(!is_long_range_broken()) return;

      if(currentLongDirectionOfBreakout != "both"){
        find_and_save_long_turning_point();
        isInLongRange = false;
      } else {
        isInLongRange = true;
      }
    }
    if(!isInLongRange){
      if(!is_long_range_confirmed()) return;

      isInLongRange = true;
    }
  }

  // 日足
  if(!isMarketClosed){
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentBarTime == lastBarTime) return;

    lastBarTime = currentBarTime;
    check_effective_leverage();
  } else {
    // 市場閉鎖してても5分後くらいに開場される。
    // 開場のタイミングで取引を再開したいため、onTickが発火するたびに処理を再実行する。→ 足が新しくなくてもreturnしない。
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
    }
  }

  ZeroMemory(request);
  ZeroMemory(result);

  if(isInRange){
    if (!isMarketClosed && !is_range_broken()) return;

    isMarketClosed = false;
    if(currentDirectionOfBreakout != "both"){
      cancel_opposite_order(); // 市場閉鎖エラーハンドリングあり
      if (isMarketClosed) return;

      if(isBrokenOpposite()) close_opposite_positions();
      find_and_save_turning_point();
      update_all_stop_loss();
      isInRange = false;
    } else {
      close_all_positions(); // 市場閉鎖エラーハンドリングあり
      if (isMarketClosed) return;

      isInRange = true; // ブレイク足自体が新しいレンジとなる
    }
  }

  if(!isInRange){
    if(!isMarketClosed && !is_range_confirmed()) return;

    isMarketClosed = false;
    send_order_both_stop_buy_and_stop_sell(); // 市場閉鎖エラーハンドリングあり
    if (isMarketClosed) return;

    isInRange = true;
  }
}


bool isBrokenOpposite() {
  bool result;
  result = previousDirectionOfBreakout != "both" && previousDirectionOfBreakout != currentDirectionOfBreakout;
  return(result);
}
