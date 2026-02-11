//+------------------------------------------------------------------+
//|                                                      Swings.mq5  |
//|                                      Rajesh Nait, Copyright 2023 |
//|                  https://www.mql5.com/en/users/rajeshnait/seller |
//+------------------------------------------------------------------+
#property copyright "Rajesh Nait, Copyright 2023"
#property link      "https://www.mql5.com/en/users/rajeshnait/seller"
#property version   "1.01"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- input parameters
input int InputBarsToLookBack = 1000; // 過去何本まで遡るか
input int InputSwingRange = 3; // 左右何本を比較対象にするか（3,4,6,10）

const color InpSwingHighColor = clrAqua;
const color InpSwingLowColor = clrPink;
const color InpWeeklySwingHighColor = clrBlue;
const color InpWeeklySwingLowColor = clrRed;
const int InpLabelOffsetPoints = 100;
const int InpWeeklyLabelOffsetPoints = 300;
const int InpBoxHalfHeightPoints = 50;
const string SwingDailyObjectPrefix = "SWING_BOX_D1_";
const string SwingWeeklyObjectPrefix = "SWING_BOX_W1_";
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    for (int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, -1);
        if (StringFind(name, SwingDailyObjectPrefix) == 0 || StringFind(name, SwingWeeklyObjectPrefix) == 0)
            ObjectDelete(0, name);
    }
}

string MakeSwingObjectName(const string prefix, const bool isHigh, const datetime t) {
    return prefix + (isHigh ? "H_" : "L_") + IntegerToString((long)t);
}

void UpsertSwingObject(const string name, const color box_color, const datetime left_time, const datetime right_time, const double center_price) {
    double half_height = (double)InpBoxHalfHeightPoints * _Point;
    double top = center_price + half_height;
    double bottom = center_price - half_height;

    if (ObjectFind(0, name) < 0) {
        if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0, left_time, top, right_time, bottom))
            return;
    } else {
        ObjectMove(0, name, 0, left_time, top);
        ObjectMove(0, name, 1, right_time, bottom);
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, box_color);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_FILL, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    //---
    int swing_range = MathMax(1, InputSwingRange);
    int bars_to_lookback = MathMax(1, InputBarsToLookBack);

    if (rates_total < swing_range * 2 + 1)
        return (0);

    //--- 新バーがないティックでは再計算しない（確定バーのみで判定可能）
    if (prev_calculated == rates_total)
        return (rates_total);

    //--- 方向明示（デフォルト依存を避ける）
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ArraySetAsSeries(tick_volume, false);
    ArraySetAsSeries(volume, false);
    ArraySetAsSeries(spread, false);

    //--- 過去InputBarsToLookBack本まで遡る基準位置
    int base_limit = MathMax(swing_range, rates_total - bars_to_lookback);
    int end_index = rates_total - swing_range;

    //--- 初回は全対象を計算。2回目以降は影響範囲のみ差分再計算
    int start = base_limit;
    if (prev_calculated > 0)
        start = MathMax(base_limit, end_index - swing_range - 2);

    int chart_period_seconds = PeriodSeconds(_Period);
    if (chart_period_seconds <= 0)
        chart_period_seconds = 86400;

    for (int i = start; i < end_index; i++) {
        bool isSwingHigh = true;
        bool isSwingLow = true;

        for (int j = 1; j <= swing_range; j++) {
            //--- Swing High の条件
            if (high[i] <= high[i - j] || high[i] <= high[i + j]) {
                isSwingHigh = false;
            }

            //--- Swing Low の条件
            if (low[i] >= low[i - j] || low[i] >= low[i + j]) {
                isSwingLow = false;
            }

            if (!isSwingHigh && !isSwingLow)
                break;
        }

        datetime left_time = time[i];
        datetime right_time = (i + 1 < rates_total) ? time[i + 1] : (left_time + chart_period_seconds);

        if (isSwingHigh) {
            string name = MakeSwingObjectName(SwingDailyObjectPrefix, true, left_time);
            double center = high[i] + (double)InpLabelOffsetPoints * _Point;
            UpsertSwingObject(name, InpSwingHighColor, left_time, right_time, center);
        }

        if (isSwingLow) {
            string name = MakeSwingObjectName(SwingDailyObjectPrefix, false, left_time);
            double center = low[i] - (double)InpLabelOffsetPoints * _Point;
            UpsertSwingObject(name, InpSwingLowColor, left_time, right_time, center);
        }
    }

    //--- 週足のSwingを日足チャート上に重ねて表示（より離すためOffsetは300）
    datetime weekly_time[];
    double weekly_high[];
    double weekly_low[];
    ArraySetAsSeries(weekly_time, false);
    ArraySetAsSeries(weekly_high, false);
    ArraySetAsSeries(weekly_low, false);

    int weekly_request = MathMax(swing_range * 2 + 1, bars_to_lookback);
    int copied_time = CopyTime(_Symbol, PERIOD_W1, 0, weekly_request, weekly_time);
    int copied_high = CopyHigh(_Symbol, PERIOD_W1, 0, weekly_request, weekly_high);
    int copied_low = CopyLow(_Symbol, PERIOD_W1, 0, weekly_request, weekly_low);
    int weekly_total = MathMin(copied_time, MathMin(copied_high, copied_low));

    if (weekly_total >= swing_range * 2 + 1) {
        for (int i = swing_range; i < weekly_total - swing_range; i++) {
            bool isWeeklySwingHigh = true;
            bool isWeeklySwingLow = true;

            for (int j = 1; j <= swing_range; j++) {
                if (weekly_high[i] <= weekly_high[i - j] || weekly_high[i] <= weekly_high[i + j])
                    isWeeklySwingHigh = false;

                if (weekly_low[i] >= weekly_low[i - j] || weekly_low[i] >= weekly_low[i + j])
                    isWeeklySwingLow = false;

                if (!isWeeklySwingHigh && !isWeeklySwingLow)
                    break;
            }

            if (isWeeklySwingHigh) {
                datetime week_open = weekly_time[i];
                datetime week_next_open = (i + 1 < weekly_total) ? weekly_time[i + 1] : (week_open + 7 * 86400);
                int day_idx = -1;
                double max_high = -DBL_MAX;

                for (int d = base_limit; d < rates_total; d++) {
                    if (time[d] < week_open || time[d] >= week_next_open)
                        continue;

                    if (high[d] > max_high) {
                        max_high = high[d];
                        day_idx = d;
                    }
                }

                if (day_idx >= 0) {
                    datetime left_time = time[day_idx];
                    datetime right_time = (day_idx + 1 < rates_total) ? time[day_idx + 1] : (left_time + chart_period_seconds);
                    string name = MakeSwingObjectName(SwingWeeklyObjectPrefix, true, left_time);
                    double center = max_high + (double)InpWeeklyLabelOffsetPoints * _Point;
                    UpsertSwingObject(name, InpWeeklySwingHighColor, left_time, right_time, center);
                }
            }

            if (isWeeklySwingLow) {
                datetime week_open = weekly_time[i];
                datetime week_next_open = (i + 1 < weekly_total) ? weekly_time[i + 1] : (week_open + 7 * 86400);
                int day_idx = -1;
                double min_low = DBL_MAX;

                for (int d = base_limit; d < rates_total; d++) {
                    if (time[d] < week_open || time[d] >= week_next_open)
                        continue;

                    if (low[d] < min_low) {
                        min_low = low[d];
                        day_idx = d;
                    }
                }

                if (day_idx >= 0) {
                    datetime left_time = time[day_idx];
                    datetime right_time = (day_idx + 1 < rates_total) ? time[day_idx + 1] : (left_time + chart_period_seconds);
                    string name = MakeSwingObjectName(SwingWeeklyObjectPrefix, false, left_time);
                    double center = min_low - (double)InpWeeklyLabelOffsetPoints * _Point;
                    UpsertSwingObject(name, InpWeeklySwingLowColor, left_time, right_time, center);
                }
            }
        }
    }

    //--- return value of prev_calculated for next call
    return (rates_total);
}

//+------------------------------------------------------------------+
