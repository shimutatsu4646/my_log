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
const color InpSwingLowColor = clrRed;
const int InpLabelOffsetPoints = 100;
const int InpBoxHalfHeightPoints = 50;
const string SwingObjectPrefix = "SWING_BOX_";
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
        if (StringFind(name, SwingObjectPrefix) == 0)
            ObjectDelete(0, name);
    }
}

string MakeSwingObjectName(const bool isHigh, const datetime t) {
    return SwingObjectPrefix + (isHigh ? "H_" : "L_") + IntegerToString((long)t);
}

void UpsertSwingObject(const bool isHigh, const int index, const int rates_total, const datetime &time[], const double &high[], const double &low[]) {
    string name = MakeSwingObjectName(isHigh, time[index]);
    double offset = (double)InpLabelOffsetPoints * _Point;
    double center = isHigh ? (high[index] + offset) : (low[index] - offset);
    double half_height = (double)InpBoxHalfHeightPoints * _Point;
    double top = center + half_height;
    double bottom = center - half_height;
    datetime right_time = (index + 1 < rates_total) ? time[index + 1] : (time[index] + PeriodSeconds(_Period));

    if (ObjectFind(0, name) < 0) {
        if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[index], top, right_time, bottom))
            return;
    } else {
        ObjectMove(0, name, 0, time[index], top);
        ObjectMove(0, name, 1, right_time, bottom);
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, isHigh ? InpSwingHighColor : InpSwingLowColor);
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

        if (isSwingHigh)
            UpsertSwingObject(true, i, rates_total, time, high, low);

        if (isSwingLow)
            UpsertSwingObject(false, i, rates_total, time, high, low);
    }

    //--- return value of prev_calculated for next call
    return (rates_total);
}

//+------------------------------------------------------------------+
