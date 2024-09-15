//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <MyCode/range_line.mqh>
#include <MyCode/print_error.mqh>
#include <MyCode/asset_management.mqh>
#include <MyCode/handle_order.mqh>
#include <MyCode/turning_point.mqh>
#include <MyCode/check_range.mqh>

// 自分で定義した関数と関数内で定義した変数は、snake_caseにする。

input double high; // 高値
input double low; // 安値
// ↓今回、レンジのどちらに抜けたか
input string current_direction_of_breakout; // [current] below=下抜け、avobe=上抜け
// ↓前のレンジ抜けの方向
input string previous_direction_of_breakout; // [previous] below=下抜け、avobe=上抜け

input ulong expertMagic = 10;
// global variables
double highOfRange; // 高値
double lowOfRange; // 安値
string currentDirectionOfBreakout;
string previousDirectionOfBreakout;
bool isInRange;
double comparativeHigh; // ブレイク中の比較対象の足の高値
double comparativeLow; // ブレイク中の比較対象の足の安値
datetime lastBarTime; // 最後に確認したバーの時間を格納する変数
MqlTradeRequest request;
MqlTradeResult result;
// 市場閉鎖でSendOrderがエラー発生した場合true
// cancel_opposite_orderでのみ発生している前提のロジックとなっている。
bool isRetcodeMarketClosed;
// int fillType;

int OnInit()
{
  highOfRange = high;
  lowOfRange = low;
  currentDirectionOfBreakout = current_direction_of_breakout;
  previousDirectionOfBreakout = previous_direction_of_breakout;
  send_order_both_stop_buy_and_stop_sell();
  isInRange = true;
  comparativeHigh = 0.0;
  comparativeLow = 0.0;
  lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
  isRetcodeMarketClosed = false;
  // fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  LineCreate("high");
  LineCreate("low");
  ChartRedraw();
  return(INIT_SUCCEEDED);
}

void OnTick()
{
  if(!isRetcodeMarketClosed){
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentBarTime == lastBarTime) return;

    lastBarTime = currentBarTime;
    check_effective_leverage();
  } else {
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
    }
  }

  ZeroMemory(request);
  ZeroMemory(result);

  if(isInRange){
    if (!isRetcodeMarketClosed && !is_range_broken()) return;

    isRetcodeMarketClosed = false;
    if(currentDirectionOfBreakout != "both"){
      // 市場閉鎖エラーが発生した場合、isRetcodeMarketClosedをtrueにするロジックを含む↓
      cancel_opposite_order();
      if (isRetcodeMarketClosed) return;

      if(previousDirectionOfBreakout != "both" && previousDirectionOfBreakout != currentDirectionOfBreakout)
      {
        // 前回のブレイク方向とは逆側にブレイクした場合
        close_opposite_positions();
      }

      find_and_save_turning_point();
      update_all_stop_loss();
      isInRange = false;
    } else {
      // currentDirectionOfBreakout == both
      // TODO: cancel_opposite_orderと同じく市場エラー発生するかも
      close_all_positions();
      // if (isRetcodeMarketClosed) return;

      // レンジブレイクした足自体が新しいレンジとなるためレンジ内
      isInRange = true;
    }
  }

  if(!isInRange){
    if(!isRetcodeMarketClosed && !is_range_confirmed()) return;

    isRetcodeMarketClosed = false;
    // 市場閉鎖エラーが発生した場合、isRetcodeMarketClosedをtrueにするロジックを含む↓
    send_order_both_stop_buy_and_stop_sell();
    if (isRetcodeMarketClosed) return;

    isInRange = true;
  }
}
