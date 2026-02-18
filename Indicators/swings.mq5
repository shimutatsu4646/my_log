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
input int InputSwingSpan = 3;         // 左右何本を比較対象にするか（3,4,6,10）

const color InpSwingHighColor = clrAqua;
const color InpSwingLowColor = clrPink;
const color InpLongTermSwingHighColor = clrBlue;
const color InpLongTermSwingLowColor = clrRed;
const int InpLabelOffsetPoints = 100;
const int InpLongTermLabelOffsetPoints = 300;
const int InpSwingMarkerFontSize = 8;
const string SwingDailyObjectPrefix = "SWING_BOX_D1_";
const string SwingLongTermObjectPrefix = "SWING_BOX_LONGTERM_";
const string DirectionBackgroundPrefix = "SWING_BG_D1_";
const string DirectionChartLabelName = "SWING_DIRECTION_CHART_TF";
const string DirectionLongTermLabelName = "SWING_DIRECTION_LONGTERM_TF";
const int DirectionLabelX = 12;
const int DirectionChartLabelY = 20;
const int DirectionLongTermLabelY = 42;
const color BgColorUp = clrHoneydew;
const color BgColorDown = clrMistyRose;

enum SwingDirection {
    SWING_DIR_UNKNOWN = 0,
    SWING_DIR_UP = 1,
    SWING_DIR_DOWN = 2,
    SWING_DIR_RANDOM = 3
};

enum GazeState {
    GAZE_UNKNOWN = 0,
    GAZE_BULLISH = 1,
    GAZE_BEARISH = 2
};

int GazeOrder(const GazeState gaze) {
    if (gaze == GAZE_BULLISH)
        return 1;
    if (gaze == GAZE_BEARISH)
        return 2;
    return 0;
}

int OnInit() {
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    ChartSetInteger(0, CHART_FOREGROUND, true);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    for (int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, -1);
        if (StringFind(name, SwingDailyObjectPrefix) == 0 ||
            StringFind(name, SwingLongTermObjectPrefix) == 0 ||
            StringFind(name, DirectionBackgroundPrefix) == 0)
            ObjectDelete(0, name);
    }
    ObjectDelete(0, DirectionChartLabelName);
    ObjectDelete(0, DirectionLongTermLabelName);
}

string MakeSwingObjectName(const string prefix, const bool isHigh, const datetime t) {
    return prefix + (isHigh ? "H_" : "L_") + IntegerToString((long)t);
}

void UpsertSwingObject(const string name, const color box_color, const datetime left_time, const double center_price) {
    int obj_index = ObjectFind(0, name);
    if (obj_index < 0) {
        if (!ObjectCreate(0, name, OBJ_TEXT, 0, left_time, center_price))
            return;
    } else {
        int obj_type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
        if (obj_type != OBJ_TEXT) {
            ObjectDelete(0, name);
            if (!ObjectCreate(0, name, OBJ_TEXT, 0, left_time, center_price))
                return;
        } else {
            ObjectMove(0, name, 0, left_time, center_price);
        }
    }

    ObjectSetString(0, name, OBJPROP_TEXT, "■");
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpSwingMarkerFontSize);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetInteger(0, name, OBJPROP_COLOR, box_color);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

SwingDirection DetectSwingDirection(const bool has_high_latest,
                                    const bool has_high_prev,
                                    const bool has_low_latest,
                                    const bool has_low_prev,
                                    const double high_latest,
                                    const double high_prev,
                                    const double low_latest,
                                    const double low_prev) {
    if (!has_high_latest || !has_high_prev || !has_low_latest || !has_low_prev)
        return SWING_DIR_UNKNOWN;

    if (high_latest > high_prev && low_latest > low_prev)
        return SWING_DIR_UP;

    if (high_latest < high_prev && low_latest < low_prev)
        return SWING_DIR_DOWN;

    return SWING_DIR_RANDOM;
}

SwingDirection UpdateDirectionByBreakout(const SwingDirection current_direction,
                                         const bool has_ref_high,
                                         const double ref_high,
                                         const bool has_ref_low,
                                         const double ref_low,
                                         const bool has_last_confirmed_high,
                                         const double last_confirmed_high,
                                         const bool has_last_confirmed_low,
                                         const double last_confirmed_low,
                                         const bool has_higher_high_ready,
                                         const bool has_higher_low_ready,
                                         const bool has_lower_high_ready,
                                         const bool has_lower_low_ready,
                                         const double bar_body_high,
                                         const double bar_body_low) {
    bool up_break_on_ref = has_ref_high && (bar_body_high > ref_high);
    bool down_break_on_ref = has_ref_low && (bar_body_low < ref_low);
    bool up_break_on_last = has_last_confirmed_high && (bar_body_high > last_confirmed_high);
    bool down_break_on_last = has_last_confirmed_low && (bar_body_low < last_confirmed_low);
    bool up_break = up_break_on_ref || up_break_on_last;
    bool down_break = down_break_on_ref || down_break_on_last;

    if (current_direction == SWING_DIR_UP) {
        if (down_break && has_lower_high_ready && has_lower_low_ready)
            return SWING_DIR_DOWN;
        if (down_break)
            return SWING_DIR_RANDOM;
        return SWING_DIR_UP;
    }

    if (current_direction == SWING_DIR_DOWN) {
        if (up_break && has_higher_high_ready && has_higher_low_ready)
            return SWING_DIR_UP;
        if (up_break)
            return SWING_DIR_RANDOM;
        return SWING_DIR_DOWN;
    }

    return current_direction;
}

void UpsertDirectionLabel(const string name, const int y_distance, const string text, const color text_color) {
    if (ObjectFind(0, name) < 0) {
        if (!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
            return;
    }

    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DirectionLabelX);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpsertDirectionStatusLabel(const string name,
                                const int y_distance,
                                const string title,
                                const SwingDirection direction,
                                const color up_color,
                                const color down_color) {
    string status = "RANDOM";
    color status_color = down_color;

    if (direction == SWING_DIR_UP) {
        status = "UP";
        status_color = up_color;
    } else if (direction == SWING_DIR_DOWN) {
        status = "DOWN";
        status_color = down_color;
    } else if (direction == SWING_DIR_UNKNOWN) {
        status = "UNKNOWN";
        status_color = up_color;
    }

    UpsertDirectionLabel(name, y_distance, title + ": " + status, status_color);
}

void DeleteObjectsByPrefix(const string prefix) {
    for (int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, -1);
        if (StringFind(name, prefix) == 0)
            ObjectDelete(0, name);
    }
}

color GetGazeBackgroundColor(const GazeState gaze) {
    if (gaze == GAZE_BULLISH)
        return BgColorUp;
    if (gaze == GAZE_BEARISH)
        return BgColorDown;
    return clrNONE;
}

void DrawDirectionBackgroundSegment(const int segment_start,
                                    const int segment_end,
                                    const GazeState gaze,
                                    const int rates_total,
                                    const int chart_period_seconds,
                                    const datetime &time[],
                                    const double &high[],
                                    const double &low[],
                                    const bool use_fixed_bounds,
                                    const double fixed_top,
                                    const double fixed_bottom) {
    if (gaze == GAZE_UNKNOWN || segment_end < segment_start)
        return;

    double segment_top = fixed_top;
    double segment_bottom = fixed_bottom;
    if (!use_fixed_bounds) {
        segment_top = -DBL_MAX;
        segment_bottom = DBL_MAX;
        for (int i = segment_start; i <= segment_end; i++) {
            if (high[i] > segment_top)
                segment_top = high[i];
            if (low[i] < segment_bottom)
                segment_bottom = low[i];
        }
    }

    if (segment_top <= segment_bottom)
        return;

    datetime left_time = time[segment_start];
    datetime right_time = (segment_end + 1 < rates_total) ? time[segment_end + 1] : (time[segment_end] + chart_period_seconds);
    string name = DirectionBackgroundPrefix + IntegerToString((long)left_time) + "_" + IntegerToString(GazeOrder(gaze));

    if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0, left_time, segment_top, right_time, segment_bottom))
        return;

    ObjectSetInteger(0, name, OBJPROP_COLOR, GetGazeBackgroundColor(gaze));
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_FILL, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

ENUM_TIMEFRAMES GetLongTermTimeframe(const ENUM_TIMEFRAMES chart_tf) {
    switch (chart_tf) {
        case PERIOD_M5:
            return PERIOD_H1;
        case PERIOD_M15:
            return PERIOD_H1;
        case PERIOD_H1:
            return PERIOD_H4;
        case PERIOD_H4:
            return PERIOD_D1;
        case PERIOD_D1:
            return PERIOD_W1;
        case PERIOD_W1:
            return PERIOD_MN1;
        default:
            return PERIOD_W1;
    }
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
                const int &spread[]) {
    int swing_span = MathMax(1, InputSwingSpan);
    int bars_to_lookback = MathMax(1, InputBarsToLookBack);

    if (rates_total < swing_span * 2 + 1)
        return (0);

    if (prev_calculated == rates_total)
        return (rates_total);

    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ArraySetAsSeries(tick_volume, false);
    ArraySetAsSeries(volume, false);
    ArraySetAsSeries(spread, false);

    int base_limit = MathMax(swing_span, rates_total - bars_to_lookback);
    int end_index = rates_total - swing_span;
    int start = base_limit;

    int chart_period_seconds = PeriodSeconds(_Period);
    if (chart_period_seconds <= 0)
        chart_period_seconds = 86400;

    bool has_confirmed_chart_swing_high = false;
    bool has_confirmed_chart_swing_low = false;
    double confirmed_chart_swing_high = 0.0;
    double confirmed_chart_swing_low = 0.0;
    double confirmed_chart_swing_body_high = 0.0;
    double confirmed_chart_swing_body_low = 0.0;
    int last_confirmed_chart_swing_type = 0; // 0:none, 1:high, 2:low

    bool has_pullback_low_ref = false;
    bool has_rebound_high_ref = false;
    double pullback_low_ref = 0.0;
    double rebound_high_ref = 0.0;
    bool has_latest_chart_swing_high = false;
    bool has_latest_chart_swing_low = false;
    double latest_chart_swing_high = 0.0;
    double latest_chart_swing_low = 0.0;
    bool pending_up_break = false;
    bool pending_down_break = false;
    bool has_higher_high_ready = false;
    bool has_higher_low_ready = false;
    bool has_lower_high_ready = false;
    bool has_lower_low_ready = false;
    SwingDirection current_chart_direction = SWING_DIR_UNKNOWN;
    GazeState current_gaze = GAZE_UNKNOWN;

    SwingDirection chart_direction_series[];
    GazeState gaze_series[];
    ArrayResize(chart_direction_series, rates_total);
    ArrayResize(gaze_series, rates_total);
    for (int i = 0; i < rates_total; i++) {
        chart_direction_series[i] = SWING_DIR_UNKNOWN;
        gaze_series[i] = GAZE_UNKNOWN;
    }

    for (int i = start; i < end_index; i++) {
        bool isSwingHigh = true;
        bool isSwingLow = true;

        for (int j = 1; j <= swing_span; j++) {
            if (high[i] <= high[i - j] || high[i] <= high[i + j])
                isSwingHigh = false;
            if (low[i] >= low[i - j] || low[i] >= low[i + j])
                isSwingLow = false;
            if (!isSwingHigh && !isSwingLow)
                break;
        }

        datetime left_time = time[i];
        if (isSwingHigh) {
            string name = MakeSwingObjectName(SwingDailyObjectPrefix, true, left_time);
            double center = high[i] + (double)InpLabelOffsetPoints * _Point;
            UpsertSwingObject(name, InpSwingHighColor, left_time, center);
            latest_chart_swing_high = high[i];
            has_latest_chart_swing_high = true;
            // 下目線中は、戻り高値より低いswing高値が確定したら戻り高値を切り下げる
            if (current_gaze == GAZE_BEARISH) {
                if (!has_rebound_high_ref || high[i] < rebound_high_ref) {
                    rebound_high_ref = high[i];
                    has_rebound_high_ref = true;
                }
            }
        }
        if (isSwingLow) {
            string name = MakeSwingObjectName(SwingDailyObjectPrefix, false, left_time);
            double center = low[i] - (double)InpLabelOffsetPoints * _Point;
            UpsertSwingObject(name, InpSwingLowColor, left_time, center);
            latest_chart_swing_low = low[i];
            has_latest_chart_swing_low = true;
            // 上目線中は、押し安値より高いswing安値が確定したら押し安値を切り上げる
            if (current_gaze == GAZE_BULLISH) {
                if (!has_pullback_low_ref || low[i] > pullback_low_ref) {
                    pullback_low_ref = low[i];
                    has_pullback_low_ref = true;
                }
            }
        }

        double bar_body_high = MathMax(open[i], close[i]);
        double bar_body_low = MathMin(open[i], close[i]);
        double rebound_break_ref = has_rebound_high_ref ? rebound_high_ref : confirmed_chart_swing_high;
        double pullback_break_ref = has_pullback_low_ref ? pullback_low_ref : confirmed_chart_swing_low;
        bool has_rebound_break_ref = has_rebound_high_ref || has_confirmed_chart_swing_high;
        bool has_pullback_break_ref = has_pullback_low_ref || has_confirmed_chart_swing_low;
        bool up_break_on_rebound_high = has_rebound_break_ref && (bar_body_high > rebound_break_ref);
        bool down_break_on_pullback_low = has_pullback_break_ref && (bar_body_low < pullback_break_ref);

        // 起点更新はブレイク発生時点の「直近swing」を採用する
        if (up_break_on_rebound_high && has_latest_chart_swing_low) {
            if (!has_pullback_low_ref || latest_chart_swing_low >= pullback_low_ref) {
                pullback_low_ref = latest_chart_swing_low;
                has_pullback_low_ref = true;
            }
        }
        if (down_break_on_pullback_low && has_latest_chart_swing_high) {
            if (!has_rebound_high_ref || latest_chart_swing_high <= rebound_high_ref) {
                rebound_high_ref = latest_chart_swing_high;
                has_rebound_high_ref = true;
            }
        }

        // 目線は押し安値/戻り高値ブレイクのみで切替
        GazeState prev_gaze = current_gaze;
        if (up_break_on_rebound_high && !down_break_on_pullback_low) {
            current_gaze = GAZE_BULLISH;
        } else if (down_break_on_pullback_low && !up_break_on_rebound_high) {
            current_gaze = GAZE_BEARISH;
        }
        // 目線反転時は、反対側参照点をリセットして古い基準値の残留を防ぐ
        if (prev_gaze != current_gaze) {
            if (current_gaze == GAZE_BULLISH) {
                has_rebound_high_ref = false;
            } else if (current_gaze == GAZE_BEARISH) {
                has_pullback_low_ref = false;
            }
        }

        SwingDirection prev_chart_direction = current_chart_direction;
        current_chart_direction = UpdateDirectionByBreakout(
            current_chart_direction,
            has_rebound_high_ref, rebound_high_ref,
            has_pullback_low_ref, pullback_low_ref,
            has_confirmed_chart_swing_high, confirmed_chart_swing_high,
            has_confirmed_chart_swing_low, confirmed_chart_swing_low,
            has_higher_high_ready, has_higher_low_ready,
            has_lower_high_ready, has_lower_low_ready,
            bar_body_high, bar_body_low
        );

        if ((prev_chart_direction == SWING_DIR_UP || prev_chart_direction == SWING_DIR_DOWN) &&
            current_chart_direction == SWING_DIR_RANDOM) {
            pending_up_break = false;
            pending_down_break = false;
        }

        if (current_chart_direction == SWING_DIR_RANDOM || current_chart_direction == SWING_DIR_UNKNOWN) {
            if (up_break_on_rebound_high && !down_break_on_pullback_low)
                pending_up_break = true;
            if (down_break_on_pullback_low && !up_break_on_rebound_high)
                pending_down_break = true;
            if (up_break_on_rebound_high && down_break_on_pullback_low) {
                pending_up_break = false;
                pending_down_break = false;
            }

            if (pending_up_break && has_higher_high_ready && has_higher_low_ready) {
                current_chart_direction = SWING_DIR_UP;
                pending_up_break = false;
                pending_down_break = false;
            } else if (pending_down_break && has_lower_high_ready && has_lower_low_ready) {
                current_chart_direction = SWING_DIR_DOWN;
                pending_up_break = false;
                pending_down_break = false;
            }
        }

        if (isSwingHigh) {
            if (last_confirmed_chart_swing_type != 1) {
                bool had_prev_high = has_confirmed_chart_swing_high;
                double prev_high_wick = confirmed_chart_swing_high;
                confirmed_chart_swing_high = high[i];
                confirmed_chart_swing_body_high = MathMax(open[i], close[i]);
                has_confirmed_chart_swing_high = true;
                last_confirmed_chart_swing_type = 1;
                has_higher_high_ready = had_prev_high && (confirmed_chart_swing_body_high > prev_high_wick);
                has_lower_high_ready = had_prev_high && (confirmed_chart_swing_body_high < prev_high_wick);

                if ((current_chart_direction == SWING_DIR_RANDOM || current_chart_direction == SWING_DIR_UNKNOWN) &&
                    pending_down_break && has_lower_high_ready && has_lower_low_ready) {
                    current_chart_direction = SWING_DIR_DOWN;
                    pending_down_break = false;
                    pending_up_break = false;
                }
            }
        }

        if (isSwingLow) {
            if (last_confirmed_chart_swing_type != 2) {
                bool had_prev_low = has_confirmed_chart_swing_low;
                double prev_low_wick = confirmed_chart_swing_low;
                confirmed_chart_swing_low = low[i];
                confirmed_chart_swing_body_low = MathMin(open[i], close[i]);
                has_confirmed_chart_swing_low = true;
                last_confirmed_chart_swing_type = 2;
                has_lower_low_ready = had_prev_low && (confirmed_chart_swing_body_low < prev_low_wick);
                has_higher_low_ready = had_prev_low && (confirmed_chart_swing_body_low > prev_low_wick);

                if ((current_chart_direction == SWING_DIR_RANDOM || current_chart_direction == SWING_DIR_UNKNOWN) &&
                    pending_up_break && has_higher_high_ready && has_higher_low_ready) {
                    current_chart_direction = SWING_DIR_UP;
                    pending_up_break = false;
                    pending_down_break = false;
                }
            }
        }

        chart_direction_series[i] = current_chart_direction;
        gaze_series[i] = current_gaze;
    }

    DeleteObjectsByPrefix(DirectionBackgroundPrefix);
    int bg_start = base_limit;
    int bg_end = end_index - 1;
    if (bg_end >= bg_start) {
        int segment_start = bg_start;
        GazeState segment_gaze = gaze_series[bg_start];

        for (int i = bg_start + 1; i <= bg_end; i++) {
            bool gaze_changed = (gaze_series[i] != segment_gaze);
            if (gaze_changed) {
                DrawDirectionBackgroundSegment(
                    segment_start, i - 1, segment_gaze,
                    rates_total, chart_period_seconds, time, high, low,
                    false, 0.0, 0.0
                );
                segment_start = i;
                segment_gaze = gaze_series[i];
            }
        }

        DrawDirectionBackgroundSegment(
            segment_start, bg_end, segment_gaze,
            rates_total, chart_period_seconds, time, high, low,
            false, 0.0, 0.0
        );
    }

    ENUM_TIMEFRAMES long_term_tf = GetLongTermTimeframe((ENUM_TIMEFRAMES)_Period);
    datetime long_term_time[];
    double long_term_open[];
    double long_term_high[];
    double long_term_low[];
    double long_term_close[];
    ArraySetAsSeries(long_term_time, false);
    ArraySetAsSeries(long_term_open, false);
    ArraySetAsSeries(long_term_high, false);
    ArraySetAsSeries(long_term_low, false);
    ArraySetAsSeries(long_term_close, false);

    int long_term_tf_seconds = PeriodSeconds(long_term_tf);
    if (long_term_tf_seconds <= 0)
        long_term_tf_seconds = 7 * 86400;

    int long_term_request = MathMax(
        swing_span * 2 + 1,
        (int)MathCeil((double)bars_to_lookback * (double)chart_period_seconds / (double)long_term_tf_seconds) + swing_span * 4
    );
    int copied_time = CopyTime(_Symbol, long_term_tf, 0, long_term_request, long_term_time);
    int copied_open = CopyOpen(_Symbol, long_term_tf, 0, long_term_request, long_term_open);
    int copied_high = CopyHigh(_Symbol, long_term_tf, 0, long_term_request, long_term_high);
    int copied_low = CopyLow(_Symbol, long_term_tf, 0, long_term_request, long_term_low);
    int copied_close = CopyClose(_Symbol, long_term_tf, 0, long_term_request, long_term_close);
    int long_term_total = MathMin(copied_time, MathMin(copied_high, copied_low));
    bool has_long_term_body_data = (copied_open >= long_term_total && copied_close >= long_term_total && long_term_total > 0);

    bool has_long_term_high_latest = false;
    bool has_long_term_high_prev = false;
    bool has_long_term_low_latest = false;
    bool has_long_term_low_prev = false;
    double long_term_high_latest = 0.0;
    double long_term_high_prev = 0.0;
    double long_term_low_latest = 0.0;
    double long_term_low_prev = 0.0;
    bool has_prev_long_term_high_wick = false;
    bool has_prev_long_term_low_wick = false;
    double prev_long_term_high_wick = 0.0;
    double prev_long_term_low_wick = 0.0;
    int last_long_term_swing_type = 0;

    if (long_term_total >= swing_span * 2 + 1) {
        for (int i = swing_span; i < long_term_total - swing_span; i++) {
            bool isLongTermSwingHigh = true;
            bool isLongTermSwingLow = true;
            for (int j = 1; j <= swing_span; j++) {
                if (long_term_high[i] <= long_term_high[i - j] || long_term_high[i] <= long_term_high[i + j])
                    isLongTermSwingHigh = false;
                if (long_term_low[i] >= long_term_low[i - j] || long_term_low[i] >= long_term_low[i + j])
                    isLongTermSwingLow = false;
                if (!isLongTermSwingHigh && !isLongTermSwingLow)
                    break;
            }

            if (isLongTermSwingHigh) {
                if (last_long_term_swing_type != 1) {
                    double body_high = has_long_term_body_data ? MathMax(long_term_open[i], long_term_close[i]) : long_term_high[i];
                    long_term_high_latest = body_high;
                    has_long_term_high_latest = true;
                    if (has_prev_long_term_high_wick) {
                        long_term_high_prev = prev_long_term_high_wick;
                        has_long_term_high_prev = true;
                    }
                    prev_long_term_high_wick = long_term_high[i];
                    has_prev_long_term_high_wick = true;
                    last_long_term_swing_type = 1;
                }

                datetime long_term_bar_open_time = long_term_time[i];
                datetime long_term_next_open_time = (i + 1 < long_term_total) ? long_term_time[i + 1] : (long_term_bar_open_time + long_term_tf_seconds);
                int day_idx = -1;
                double max_high = -DBL_MAX;
                for (int d = base_limit; d < rates_total; d++) {
                    if (time[d] < long_term_bar_open_time || time[d] >= long_term_next_open_time)
                        continue;
                    if (high[d] > max_high) {
                        max_high = high[d];
                        day_idx = d;
                    }
                }
                if (day_idx >= 0) {
                    datetime marker_time = time[day_idx];
                    string name = MakeSwingObjectName(SwingLongTermObjectPrefix, true, marker_time);
                    double center = max_high + (double)InpLongTermLabelOffsetPoints * _Point;
                    UpsertSwingObject(name, InpLongTermSwingHighColor, marker_time, center);
                }
            }

            if (isLongTermSwingLow) {
                if (last_long_term_swing_type != 2) {
                    double body_low = has_long_term_body_data ? MathMin(long_term_open[i], long_term_close[i]) : long_term_low[i];
                    long_term_low_latest = body_low;
                    has_long_term_low_latest = true;
                    if (has_prev_long_term_low_wick) {
                        long_term_low_prev = prev_long_term_low_wick;
                        has_long_term_low_prev = true;
                    }
                    prev_long_term_low_wick = long_term_low[i];
                    has_prev_long_term_low_wick = true;
                    last_long_term_swing_type = 2;
                }

                datetime long_term_bar_open_time = long_term_time[i];
                datetime long_term_next_open_time = (i + 1 < long_term_total) ? long_term_time[i + 1] : (long_term_bar_open_time + long_term_tf_seconds);
                int day_idx = -1;
                double min_low = DBL_MAX;
                for (int d = base_limit; d < rates_total; d++) {
                    if (time[d] < long_term_bar_open_time || time[d] >= long_term_next_open_time)
                        continue;
                    if (low[d] < min_low) {
                        min_low = low[d];
                        day_idx = d;
                    }
                }
                if (day_idx >= 0) {
                    datetime marker_time = time[day_idx];
                    string name = MakeSwingObjectName(SwingLongTermObjectPrefix, false, marker_time);
                    double center = min_low - (double)InpLongTermLabelOffsetPoints * _Point;
                    UpsertSwingObject(name, InpLongTermSwingLowColor, marker_time, center);
                }
            }
        }
    }

    SwingDirection daily_direction = current_chart_direction;
    SwingDirection long_term_direction = DetectSwingDirection(
        has_long_term_high_latest, has_long_term_high_prev, has_long_term_low_latest, has_long_term_low_prev,
        long_term_high_latest, long_term_high_prev, long_term_low_latest, long_term_low_prev
    );

    UpsertDirectionStatusLabel(
        DirectionChartLabelName,
        DirectionChartLabelY,
        "Chart TF Direction",
        daily_direction,
        clrWhite,
        clrWhite
    );
    UpsertDirectionStatusLabel(
        DirectionLongTermLabelName,
        DirectionLongTermLabelY,
        "LongTerm TF Direction",
        long_term_direction,
        clrWhite,
        clrWhite
    );

    return (rates_total);
}

//+------------------------------------------------------------------+
