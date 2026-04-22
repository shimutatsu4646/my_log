#ifndef SABAI_SYSTEM_TYPES_MQH
#define SABAI_SYSTEM_TYPES_MQH

enum MarketPhase {
    PHASE_UNKNOWN     = 0,
    PHASE_UP_TREND    = 1,
    PHASE_DOWN_TREND  = 2,
    PHASE_RANGE       = 3,
    PHASE_RANDOM      = 4
};

enum BiasDirection {
    BIAS_UNKNOWN  = 0,
    BIAS_BULLISH  = 1,
    BIAS_BEARISH  = 2
};

enum SwingType {
    SWING_NONE = 0,
    SWING_HIGH = 1,
    SWING_LOW  = 2
};

struct SwingPoint {
    double   price;
    double   body_price;
    datetime time;
    int      bar_index;
    bool     is_valid;

    void Reset() {
        price      = 0.0;
        body_price = 0.0;
        time       = 0;
        bar_index  = -1;
        is_valid   = false;
    }
};

struct RangeZone {
    double   upper_bound;
    double   lower_bound;
    datetime upper_start_time;
    datetime lower_start_time;
    datetime confirmed_time;
    datetime ended_time;
    bool     is_active;

    // ネスト時に親レンジの上限/下限を共有しているかを示すフラグ。
    // shared 側のラインは親レンジ側で描画されるため、子側では描画しない。
    bool     shares_upper_with_parent;
    bool     shares_lower_with_parent;
    int      parent_range_idx;

    void Reset() {
        upper_bound      = 0.0;
        lower_bound      = 0.0;
        upper_start_time = 0;
        lower_start_time = 0;
        confirmed_time   = 0;
        ended_time       = 0;
        is_active        = false;
        shares_upper_with_parent = false;
        shares_lower_with_parent = false;
        parent_range_idx         = -1;
    }
};

struct QuickBiasState {
    BiasDirection direction;
    SwingPoint    anchor_low;
    SwingPoint    anchor_high;
    SwingPoint    tracking_high;
    SwingPoint    tracking_low;

    void Reset() {
        direction = BIAS_UNKNOWN;
        anchor_low.Reset();
        anchor_high.Reset();
        tracking_high.Reset();
        tracking_low.Reset();
    }
};

struct SlowBiasState {
    BiasDirection direction;
    SwingPoint    pullback_low;
    SwingPoint    rebound_high;
    SwingPoint    highest_high;
    SwingPoint    lowest_low;

    void Reset() {
        direction = BIAS_UNKNOWN;
        pullback_low.Reset();
        rebound_high.Reset();
        highest_high.Reset();
        lowest_low.Reset();
    }
};

struct TimeframeState {
    ENUM_TIMEFRAMES  timeframe;
    MarketPhase      current_phase;
    QuickBiasState   quick_bias;
    SlowBiasState    slow_bias;
    RangeZone        active_ranges[];

    SwingPoint       first_wave_start;
    SwingPoint       first_wave_end;
    bool             has_first_wave;

    void Reset() {
        timeframe     = PERIOD_CURRENT;
        current_phase = PHASE_UNKNOWN;
        quick_bias.Reset();
        slow_bias.Reset();
        ArrayFree(active_ranges);
        first_wave_start.Reset();
        first_wave_end.Reset();
        has_first_wave = false;
    }
};

string MarketPhaseToString(const MarketPhase phase) {
    switch (phase) {
        case PHASE_UP_TREND:    return "up_trend";
        case PHASE_DOWN_TREND:  return "down_trend";
        case PHASE_RANGE:       return "range";
        case PHASE_RANDOM:      return "random";
        default:                return "unknown";
    }
}

string BiasDirectionToString(const BiasDirection dir) {
    switch (dir) {
        case BIAS_BULLISH: return "bull";
        case BIAS_BEARISH: return "bear";
        default:           return "unknown";
    }
}

#define SABAI_MAX_TF_COUNT 5
// チャート分析の横軸ラインの幅
#define SABAI_STRUCTURE_LANDSCAPE_LINE_WIDTH 3

color GetTimeframeColor(const ENUM_TIMEFRAMES tf) {
    if (tf == PERIOD_MN1) return clrMaroon;
    if (tf == PERIOD_W1)  return clrBlue;
    if (tf == PERIOD_D1)  return clrForestGreen;
    if (tf == PERIOD_H4)  return clrDarkOrchid;
    if (tf == PERIOD_H1)  return clrAqua;
    return clrGray;
}

int GetTimeframeIndex(const ENUM_TIMEFRAMES tf) {
    if (tf == PERIOD_MN1) return 0;
    if (tf == PERIOD_W1)  return 1;
    if (tf == PERIOD_D1)  return 2;
    if (tf == PERIOD_H4)  return 3;
    if (tf == PERIOD_H1)  return 4;
    return 4;
}

ENUM_TIMEFRAMES GetTimeframeByIndex(const int idx) {
    switch (idx) {
        case 0: return PERIOD_MN1;
        case 1: return PERIOD_W1;
        case 2: return PERIOD_D1;
        case 3: return PERIOD_H4;
        case 4: return PERIOD_H1;
        default: return PERIOD_H1;
    }
}

int GetTFCount(const ENUM_TIMEFRAMES chart_tf) {
    return GetTimeframeIndex(chart_tf) + 1;
}

int GetUpperTFCount(const ENUM_TIMEFRAMES chart_tf) {
    return GetTimeframeIndex(chart_tf);
}

ENUM_TIMEFRAMES GetUpperSwingTF(const ENUM_TIMEFRAMES chart_tf) {
    int idx = GetTimeframeIndex(chart_tf);
    if (idx <= 0) return PERIOD_CURRENT;
    return GetTimeframeByIndex(idx - 1);
}

string GetTimeframeLabel(const ENUM_TIMEFRAMES tf) {
    if (tf == PERIOD_MN1) return "MN1";
    if (tf == PERIOD_W1)  return "W1";
    if (tf == PERIOD_D1)  return "D1";
    if (tf == PERIOD_H4)  return "H4";
    if (tf == PERIOD_H1)  return "H1";
    return "??";
}

// レンジラインラベル等で使用する時間軸プレフィックス。例: "D1_"
string GetTimeframePrefix(const ENUM_TIMEFRAMES tf) {
    if (tf == PERIOD_MN1) return "MN_";
    if (tf == PERIOD_W1)  return "W1_";
    if (tf == PERIOD_D1)  return "D1_";
    if (tf == PERIOD_H4)  return "H4_";
    if (tf == PERIOD_H1)  return "H1_";
    return "??_";
}

#endif
