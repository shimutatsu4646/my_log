//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#property indicator_buffers 3
#property indicator_plots   3
// dma 期間-シフト
// dma 3-3
#property indicator_label1  "SMA(3)"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
// dma 7-5
#property indicator_label2  "SMA(7)"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
// dma 25-5
#property indicator_label3  "SMA(25)"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_SOLID

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
// TODO: グローバル変数はcamelCaseにする。prefixでGlobalをつける →例）GlobalHighOfRange
// TODO: 日足→Daily、週足→Weekly →例）GlobalDailyHighOfRange, GlobalWeeklyHighOfRange
// TODO: インプット変数はprefixでInputをつける & camelCaseにする。→ 例）InputHighOfRange
// TODO: インプット変数とグローバル変数の変数名をprefix以外を完全一致させる。 例）InputHighOfRange と GlobalHighOfRange
// TODO: comparativeBar~~にする

input double high; // 日足高値(high)
input double low; // 日足安値(low)
input double longHigh; // 週足高値(longHigh)
input double longLow; // 週足安値(longLow)
// ↓今回、レンジのどちらに抜けたか
input string current_direction_of_breakout; // [current] below=下抜け、above=上抜け
// ↓前のレンジ抜けの方向
input string previous_direction_of_breakout; // [previous] below=下抜け、above=上抜け
// ↓今回、レンジのどちらに抜けたか（長期時間軸）
input string current_long_direction_of_breakout; // [current] below=下抜け、above=上抜け（長期時間軸）
// ↓前のレンジ抜けの方向（長期時間軸）
input string previous_long_direction_of_breakout; // [previous] below=下抜け、above=上抜け（長期時間軸）

input double next_turning_high; // 最新の日足高値（転換点候補）
input double next_turning_low; // 最新の日足安値（転換点候補）
input double next_turning_long_high; // 最新の週足高値（転換点候補）
input double next_turning_long_low; // 最新の週足安値（転換点候補）
input double comparative_high; // 比較対象の日足の高値
input double comparative_low; // 比較対象の日足の安値
input double comparative_long_high; // 比較対象の週足の高値
input double comparative_long_low; // 比較対象の週足の安値
input string bar_direction; // 上下どちらに足が進んでいるか。below=下・above=上・both=両方（包み足）
input string long_bar_direction; // 上下どちらに足が進んでいるか。below=下・above=上・both=両方（包み足）（週足）

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
double nextTurningHigh;
double nextTurningLow;
double nextTurningLongHigh;
double nextTurningLongLow;
bool isInRange;
bool isInLongRange;
double comparativeHigh; // ブレイク中の比較対象の足の高値
double comparativeLow; // ブレイク中の比較対象の足の安値
double comparativeLongHigh; // ブレイク中の比較対象の足の高値
double comparativeLongLow; // ブレイク中の比較対象の足の安値
string barDirection;
string longBarDirection;
datetime lastBarTime; // 最後に確認したバーの時間を格納する変数
datetime lastLongBarTime; // 最後に確認したバーの時間を格納する変数
MqlTradeRequest request;
MqlTradeResult result;
// 市場閉鎖でSendOrderがエラー発生した場合true
// cancel_opposite_orderでのみ発生している前提のロジックとなっている。
bool isMarketClosed;
bool isBrokenSameTime;
bool isBrokenSameTimeForLong;
double EffectiveLeverage;
// int fillType;
double dma3Buffer[];
double dma7Buffer[];
double dma25Buffer[];
// ハンドルをグローバル変数として保持
int ma3Handle;
int ma7Handle;
int ma25Handle;

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
  nextTurningHigh = next_turning_high;
  nextTurningLow = next_turning_low;
  nextTurningLongHigh = next_turning_long_high;
  nextTurningLongLow = next_turning_long_low;
  send_order_both_stop_buy_and_stop_sell();
  isInRange = true;
  isInLongRange = true; // inputで受け付ける方が良さそう
  comparativeHigh = comparative_high;
  comparativeLow = comparative_low;
  comparativeLongHigh = comparative_long_high;
  comparativeLongLow = comparative_long_low;
  barDirection = bar_direction;
  longBarDirection = long_bar_direction;
  lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
  lastLongBarTime = iTime(_Symbol, PERIOD_W1, 0);
  isMarketClosed = false;
  isBrokenSameTime = false;
  isBrokenSameTimeForLong = false;
  EffectiveLeverage = 0.0;
  // fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  LineCreate("high");
  LineCreate("low");
  LongLineCreate("high");
  LongLineCreate("low");
  ChartRedraw();

  // バッファの設定（順序が重要）
  SetIndexBuffer(0, dma3Buffer, INDICATOR_DATA);
  SetIndexBuffer(1, dma7Buffer, INDICATOR_DATA);
  SetIndexBuffer(2, dma25Buffer, INDICATOR_DATA);

  // 移動平均線のハンドルを取得
  ma3Handle = iMA(_Symbol, PERIOD_CURRENT, 3, 3, MODE_SMA, PRICE_CLOSE);
  ma7Handle = iMA(_Symbol, PERIOD_CURRENT, 7, 5, MODE_SMA, PRICE_CLOSE);
  ma25Handle = iMA(_Symbol, PERIOD_CURRENT, 25, 5, MODE_SMA, PRICE_CLOSE);

  return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
  // 移動平均値をバッファにコピー
  if(CopyBuffer(ma3Handle, 0, 0, rates_total, dma3Buffer) <= 0) return(0);
  if(CopyBuffer(ma7Handle, 0, 0, rates_total, dma7Buffer) <= 0) return(0);
  if(CopyBuffer(ma25Handle, 0, 0, rates_total, dma25Buffer) <= 0) return(0);

  return(rates_total);
}

void OnTick()
{
  // 週足
  change_long_timebar_data();

  // 日足
  if(!isMarketClosed){
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentBarTime == lastBarTime) return;

    lastBarTime = currentBarTime;
    isBrokenSameTime = false;
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
    if (!isMarketClosed) {
      if(is_range_broken()){
        // update_global_bar_data()はレンジ確定処理とか転換点導出などを実行してから
        isBrokenSameTime = true;
        comment_global_value();
      } else {
        update_global_bar_data();
        comment_global_value();
        return;
      }
    }
    isMarketClosed = false;
    if(currentDirectionOfBreakout != "both"){
      cancel_opposite_order(); // 市場閉鎖エラーハンドリングあり
      if (isMarketClosed) return;

      // これが実行されるときにはすでに反対側のポジションは全部損切り済みのはずだが、念の為
      if(isBrokenOpposite()) close_opposite_positions();
      isInRange = false;
    } else {
      // ↓基本的に発生しない想定。
      close_all_positions(); // 市場閉鎖エラーハンドリングあり
      if (isMarketClosed) return;

      // update_global_bar_dataは実行しない。is_range_broken内で更新するため。
      comment_global_value();
      isInRange = true; // ブレイク足自体が新しいレンジとなる
    }
  }

  if(!isInRange){
    if(!isMarketClosed){
      bool result_bool;
      result_bool = is_range_confirmed();
      if(isBrokenSameTime) { // レンジブレイクした直後
        update_range_of_turning_point();
        // ↓市場閉鎖エラーはない。cancel_opposite_order()で送信成功するまで繰り返すため。
        update_all_stop_loss();
      }
      update_global_bar_data();
      comment_global_value();
      if(result_bool == false) return;
    }

    isMarketClosed = false;
    send_order_both_stop_buy_and_stop_sell(); // 市場閉鎖エラーハンドリングあり
    if (isMarketClosed) return;

    isInRange = true;
  }
  comment_global_value();
}


bool isBrokenOpposite() {
  bool result;
  result = previousDirectionOfBreakout != "both" && previousDirectionOfBreakout != currentDirectionOfBreakout;
  return(result);
}


void change_long_timebar_data() {
  datetime currentLongBarTime = iTime(_Symbol, PERIOD_W1, 0);
  if(currentLongBarTime != lastLongBarTime) {
    lastLongBarTime = currentLongBarTime;
    isBrokenSameTimeForLong = false;
    if(isInLongRange) {
      if(is_long_range_broken()){
        isBrokenSameTimeForLong = true;
      } else {
        update_global_long_bar_data();
        return;
      }

      if(currentLongDirectionOfBreakout != "both"){
        isInLongRange = false;
      } else {
        // ↓基本的に発生しない想定
        // update_global_bar_dataは実行しない。is_range_broken内で更新するため。
        isInLongRange = true;
      }
    }

    if(!isInLongRange){
      bool result_bool;
      result_bool = is_long_range_confirmed();
      if(isBrokenSameTimeForLong) {
        update_long_range_of_turning_point();
      }
      update_global_long_bar_data();
      if(result_bool == false) return;

      isInLongRange = true;
    }
  }
}

void comment_global_value() {
  // OnInitで代入しているグローバル変数をコメントとして出力する

  string daily_range_in_or_out = isInRange ? "(Within Range)" : "(Breaking)";
  string long_range_in_or_out = isInLongRange ? "(Within Range)" : "(Breaking)";

  // グローバル変数名をDailyとWeeklyに更新して、グローバル変数のまま出力する
  Comment(StringFormat("EffectiveLeverage: %f\nDaily Range: %s / High = %f / Low = %f\nDaily Breakout Direction: Previous = %s / Current = %s\nDaily Turning Point Candidate: High = %f / Low = %f\nDaily Comparative Bar: High = %f / Low = %f\nDirection of Latest Daily Bar: %s\n\nWeekly Range: %s / High = %f / Low = %f\nWeekly Breakout Direction: Previous = %s / Current = %s\nWeekly Turning Point Candidate: High = %f / Low = %f\nWeekly Comparative Bar: High = %f / Low = %f\nDirection of Latest Weekly Bar: %s", EffectiveLeverage, daily_range_in_or_out, highOfRange, lowOfRange, previousDirectionOfBreakout, currentDirectionOfBreakout, nextTurningHigh, nextTurningLow, comparativeHigh, comparativeLow, barDirection, long_range_in_or_out, highOfLongRange, lowOfLongRange, previousLongDirectionOfBreakout, currentLongDirectionOfBreakout, nextTurningLongHigh, nextTurningLongLow, comparativeLongHigh, comparativeLongLow, longBarDirection));

}
