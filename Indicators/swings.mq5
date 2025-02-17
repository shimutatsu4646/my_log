//+------------------------------------------------------------------+
//|                                                      Swings.mq5  |
//|                                      Rajesh Nait, Copyright 2023 |
//|                  https://www.mql5.com/en/users/rajeshnait/seller |
//+------------------------------------------------------------------+
#property copyright "Rajesh Nait, Copyright 2023"
#property link      "https://www.mql5.com/en/users/rajeshnait/seller"
#property version   "1.01"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- plot Bullish Marubozu
#property indicator_label1  "+S"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot Bearish Marubozu
#property indicator_label2  "-S"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- input parameters
input group "Swing Low"
uchar InpSwingLowCode = 110; // Swing Low: code for style DRAW_ARROW (font Wingdings)
int InpSwingLowShift = 10;   // Swing Low: vertical shift of arrows in pixels
input group "Swing High"
uchar InpSwingHighCode = 110; // SwingHigh: code for style DRAW_ARROW (font Wingdings)
int InpSwingHighShift = 10;   // SwingHigh: vertical shift of arrows in pixels

// インプット変数
input int InputBarsToLookBack = 3000; // 過去何本まで遡るか
input int InputSwingRange = 6; // 左右何本を比較対象にするか

//--- indicator buffers
double SwingLowBuffer[];
double SwingHighBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    //--- indicator buffers mapping
    SetIndexBuffer(0, SwingLowBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SwingHighBuffer, INDICATOR_DATA);

    IndicatorSetInteger(INDICATOR_DIGITS, Digits());
    //--- setting a code from the Wingdings charset as the property of PLOT_ARROW
    PlotIndexSetInteger(0, PLOT_ARROW, InpSwingLowCode);
    PlotIndexSetInteger(1, PLOT_ARROW, InpSwingHighCode);
    //--- set the vertical shift of arrows in pixels
    PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, InpSwingLowShift);
    PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -InpSwingHighShift);
    //--- set as an empty value 0.0
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    //---
    return (INIT_SUCCEEDED);
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
    if (rates_total < InputSwingRange * 2 + 1)
        return (0);

    //--- 過去InputBarsToLookBack本まで遡る
    int limit = MathMax(InputSwingRange, rates_total - InputBarsToLookBack);

    //--- 初期化をループの外に移動
    SwingHighBuffer[0] = EMPTY_VALUE;
    SwingLowBuffer[0] = EMPTY_VALUE;

    for (int i = limit; i < rates_total - InputSwingRange; i++) {
        SwingLowBuffer[i] = 0.0;
        SwingHighBuffer[i] = 0.0;

        bool isSwingHigh = true;
        bool isSwingLow = true;

        for (int j = 1; j <= InputSwingRange; j++) {
            //--- Swing High の条件
            if (high[i] <= high[i - j] || high[i] <= high[i + j]) {
                isSwingHigh = false;
                break;
            }
        }
        if (isSwingHigh)
            SwingHighBuffer[i] = high[i];

        for (int j = 1; j <= InputSwingRange; j++) {
            //--- Swing Low の条件
            if (low[i] >= low[i - j] || low[i] >= low[i + j]) {
                isSwingLow = false;
                break;
            }
        }
        if (isSwingLow)
            SwingLowBuffer[i] = low[i];
    }

    //--- return value of prev_calculated for next call
    return (rates_total);
}

//+------------------------------------------------------------------+
