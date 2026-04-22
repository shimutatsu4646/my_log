#ifndef SABAI_SYSTEM_DRAWING_BIAS_RENDERER_MQH
#define SABAI_SYSTEM_DRAWING_BIAS_RENDERER_MQH

#include "../Types.mqh"
#include "../QuickBiasDetector.mqh"
#include "../SlowBiasDetector.mqh"
#include "ObjectHelper.mqh"

#define SABAI_BIAS_PREFIX         SABAI_OBJ_PREFIX "BI_"
#define SABAI_BIAS_BG_PREFIX      SABAI_BIAS_PREFIX "BG_"
#define SABAI_BIAS_SLOW_PREFIX    SABAI_BIAS_PREFIX "SL_"

class CBiasRenderer {
private:
    color m_bg_bullish;
    color m_bg_bearish;
    int   m_slow_line_width;
    int   m_line_shift_multiplier;

    struct BgSegment {
        BiasDirection direction;
        datetime      start_time;
        double        top_price;
        double        bottom_price;
    };

    BgSegment m_segments[];
    int       m_segment_count;
    int       m_segment_capacity;

    struct ActiveSlowLine {
        string   name;
        datetime start_time;
        double   price;
        color    clr;
        int      width;
        bool     active;
    };

    ActiveSlowLine m_chart_pullback;
    ActiveSlowLine m_chart_rebound;

    ActiveSlowLine m_upper_pullbacks[];
    ActiveSlowLine m_upper_rebounds[];
    int            m_upper_line_count;

    void InitSlowLine(ActiveSlowLine &line) {
        line.name       = "";
        line.start_time = 0;
        line.price      = 0.0;
        line.clr        = clrNONE;
        line.width      = SABAI_STRUCTURE_LANDSCAPE_LINE_WIDTH;
        line.active     = false;
    }

    void GrowSegments() {
        if (m_segment_count >= m_segment_capacity) {
            int new_cap = (m_segment_capacity == 0) ? 256 : m_segment_capacity * 2;
            ArrayResize(m_segments, new_cap);
            m_segment_capacity = new_cap;
        }
    }

    // 上位足の押し安値・戻り高値のyオフセットを「該当上位足がチャート足から何段上か」で決める。
    // PhaseRenderer の GetShiftedPrice と同じ段数ルールに揃える。
    double GetShiftedPrice(const double base_price,
                           const ENUM_TIMEFRAMES tf,
                           const bool shift_up) {
        int chart_idx = GetTimeframeIndex((ENUM_TIMEFRAMES)_Period);
        int step = chart_idx - GetTimeframeIndex(tf);
        if (step < 0) step = 0;
        double shift = (double)(m_line_shift_multiplier * step) * _Point;
        return shift_up ? (base_price + shift) : (base_price - shift);
    }

public:
    void Init(const color bg_bull = clrHoneydew,
              const color bg_bear = clrMistyRose,
              const int line_shift = 200) { // 上位足の押し安値・戻り高値のyオフセット
        m_bg_bullish  = bg_bull;
        m_bg_bearish  = bg_bear;
        m_slow_line_width = SABAI_STRUCTURE_LANDSCAPE_LINE_WIDTH;
        m_line_shift_multiplier = line_shift;
        m_segment_count    = 0;
        m_segment_capacity = 0;
        ArrayFree(m_segments);
        InitSlowLine(m_chart_pullback);
        InitSlowLine(m_chart_rebound);
        m_upper_line_count = 0;
        ArrayResize(m_upper_pullbacks, SABAI_MAX_TF_COUNT - 1);
        ArrayResize(m_upper_rebounds, SABAI_MAX_TF_COUNT - 1);
        for (int i = 0; i < SABAI_MAX_TF_COUNT - 1; i++) {
            InitSlowLine(m_upper_pullbacks[i]);
            InitSlowLine(m_upper_rebounds[i]);
        }
    }

    void Clear() {
        CObjectHelper::DeleteByPrefix(SABAI_BIAS_PREFIX);
        m_segment_count = 0;
        InitSlowLine(m_chart_pullback);
        InitSlowLine(m_chart_rebound);
        for (int i = 0; i < SABAI_MAX_TF_COUNT - 1; i++) {
            InitSlowLine(m_upper_pullbacks[i]);
            InitSlowLine(m_upper_rebounds[i]);
        }
    }

    void RecordBgSegment(const BiasDirection direction,
                         const datetime start_time,
                         const double top_price,
                         const double bottom_price) {
        GrowSegments();
        m_segments[m_segment_count].direction    = direction;
        m_segments[m_segment_count].start_time   = start_time;
        m_segments[m_segment_count].top_price    = top_price;
        m_segments[m_segment_count].bottom_price = bottom_price;
        m_segment_count++;
    }

    void FlushBgSegments(const int chart_period_seconds,
                         const datetime &time[],
                         const int rates_total) {
        CObjectHelper::DeleteByPrefix(SABAI_BIAS_BG_PREFIX);

        if (m_segment_count <= 0) return;

        int seg_start_idx = 0;
        BiasDirection seg_dir    = m_segments[0].direction;
        double        seg_top    = m_segments[0].top_price;
        double        seg_bottom = m_segments[0].bottom_price;

        for (int i = 1; i < m_segment_count; i++) {
            bool changed = (m_segments[i].direction != seg_dir) ||
                           (m_segments[i].top_price != seg_top) ||
                           (m_segments[i].bottom_price != seg_bottom);
            if (changed) {
                DrawBgRect(seg_dir, m_segments[seg_start_idx].start_time,
                           m_segments[i - 1].start_time,
                           seg_top, seg_bottom, chart_period_seconds);
                seg_start_idx = i;
                seg_dir    = m_segments[i].direction;
                seg_top    = m_segments[i].top_price;
                seg_bottom = m_segments[i].bottom_price;
            }
        }

        int last_idx = m_segment_count - 1;
        datetime last_right = m_segments[last_idx].start_time + chart_period_seconds;
        DrawBgRect(seg_dir, m_segments[seg_start_idx].start_time,
                   last_right, seg_top, seg_bottom, 0);
    }

    void DrawBgRect(const BiasDirection direction,
                    const datetime left_time,
                    const datetime right_time,
                    const double top_price,
                    const double bottom_price,
                    const int extra_seconds) {
        if (direction == BIAS_UNKNOWN) return;
        if (top_price <= bottom_price) return;

        color clr = (direction == BIAS_BULLISH) ? m_bg_bullish : m_bg_bearish;
        datetime right = right_time;
        if (extra_seconds > 0) right += extra_seconds;

        string name = SABAI_BIAS_BG_PREFIX +
                      IntegerToString((long)left_time) + "_" +
                      IntegerToString((direction == BIAS_BULLISH) ? 1 : 2);
        CObjectHelper::UpsertRectangle(name, left_time, top_price, right, bottom_price, clr, true);
    }

    void StartChartPullbackLine(const datetime start_time, const double price) {
        if (m_chart_pullback.active) {
            CObjectHelper::UpsertHLine(m_chart_pullback.name,
                                       m_chart_pullback.start_time, start_time,
                                       m_chart_pullback.price, m_chart_pullback.clr,
                                       STYLE_SOLID, m_chart_pullback.width);
        }
        long price_key = (long)MathRound(price / _Point);
        m_chart_pullback.name = SABAI_BIAS_SLOW_PREFIX "CPB_" +
                                IntegerToString((long)start_time) + "_" +
                                IntegerToString(price_key);
        m_chart_pullback.start_time = start_time;
        m_chart_pullback.price      = price;
        m_chart_pullback.clr        = clrLawnGreen;
        m_chart_pullback.width      = m_slow_line_width;
        m_chart_pullback.active     = true;
    }

    void CloseChartPullbackLine(const datetime end_time) {
        if (!m_chart_pullback.active) return;
        CObjectHelper::UpsertHLine(m_chart_pullback.name,
                                   m_chart_pullback.start_time, end_time,
                                   m_chart_pullback.price, m_chart_pullback.clr,
                                   STYLE_SOLID, m_chart_pullback.width);
        m_chart_pullback.active = false;
    }

    void StartChartReboundLine(const datetime start_time, const double price) {
        if (m_chart_rebound.active) {
            CObjectHelper::UpsertHLine(m_chart_rebound.name,
                                       m_chart_rebound.start_time, start_time,
                                       m_chart_rebound.price, m_chart_rebound.clr,
                                       STYLE_SOLID, m_chart_rebound.width);
        }
        long price_key = (long)MathRound(price / _Point);
        m_chart_rebound.name = SABAI_BIAS_SLOW_PREFIX "CRB_" +
                               IntegerToString((long)start_time) + "_" +
                               IntegerToString(price_key);
        m_chart_rebound.start_time = start_time;
        m_chart_rebound.price      = price;
        m_chart_rebound.clr        = clrMagenta;
        m_chart_rebound.width      = m_slow_line_width;
        m_chart_rebound.active     = true;
    }

    void CloseChartReboundLine(const datetime end_time) {
        if (!m_chart_rebound.active) return;
        CObjectHelper::UpsertHLine(m_chart_rebound.name,
                                   m_chart_rebound.start_time, end_time,
                                   m_chart_rebound.price, m_chart_rebound.clr,
                                   STYLE_SOLID, m_chart_rebound.width);
        m_chart_rebound.active = false;
    }

    void StartUpperTFPullbackLine(const int tf_slot,
                                  const ENUM_TIMEFRAMES tf,
                                  const datetime start_time,
                                  const double price) {
        if (tf_slot < 0 || tf_slot >= SABAI_MAX_TF_COUNT - 1) return;
        if (m_upper_pullbacks[tf_slot].active) {
            CObjectHelper::UpsertHLine(m_upper_pullbacks[tf_slot].name,
                                       m_upper_pullbacks[tf_slot].start_time, start_time,
                                       m_upper_pullbacks[tf_slot].price,
                                       m_upper_pullbacks[tf_slot].clr,
                                       STYLE_SOLID, m_upper_pullbacks[tf_slot].width);
        }
        color clr = GetTimeframeColor(tf);
        m_upper_pullbacks[tf_slot].name = SABAI_BIAS_SLOW_PREFIX "UPB_" +
                                          IntegerToString(tf_slot) + "_" +
                                          IntegerToString((long)start_time);
        m_upper_pullbacks[tf_slot].start_time = start_time;
        m_upper_pullbacks[tf_slot].price      = GetShiftedPrice(price, tf, false);
        m_upper_pullbacks[tf_slot].clr        = clr;
        m_upper_pullbacks[tf_slot].width      = m_slow_line_width;
        m_upper_pullbacks[tf_slot].active     = true;
    }

    void CloseUpperTFPullbackLine(const int tf_slot, const datetime end_time) {
        if (tf_slot < 0 || tf_slot >= SABAI_MAX_TF_COUNT - 1) return;
        if (!m_upper_pullbacks[tf_slot].active) return;
        CObjectHelper::UpsertHLine(m_upper_pullbacks[tf_slot].name,
                                   m_upper_pullbacks[tf_slot].start_time, end_time,
                                   m_upper_pullbacks[tf_slot].price,
                                   m_upper_pullbacks[tf_slot].clr,
                                   STYLE_SOLID, m_upper_pullbacks[tf_slot].width);
        m_upper_pullbacks[tf_slot].active = false;
    }

    void StartUpperTFReboundLine(const int tf_slot,
                                 const ENUM_TIMEFRAMES tf,
                                 const datetime start_time,
                                 const double price) {
        if (tf_slot < 0 || tf_slot >= SABAI_MAX_TF_COUNT - 1) return;
        if (m_upper_rebounds[tf_slot].active) {
            CObjectHelper::UpsertHLine(m_upper_rebounds[tf_slot].name,
                                       m_upper_rebounds[tf_slot].start_time, start_time,
                                       m_upper_rebounds[tf_slot].price,
                                       m_upper_rebounds[tf_slot].clr,
                                       STYLE_SOLID, m_upper_rebounds[tf_slot].width);
        }
        color clr = GetTimeframeColor(tf);
        m_upper_rebounds[tf_slot].name = SABAI_BIAS_SLOW_PREFIX "URB_" +
                                         IntegerToString(tf_slot) + "_" +
                                         IntegerToString((long)start_time);
        m_upper_rebounds[tf_slot].start_time = start_time;
        m_upper_rebounds[tf_slot].price      = GetShiftedPrice(price, tf, true);
        m_upper_rebounds[tf_slot].clr        = clr;
        m_upper_rebounds[tf_slot].width      = m_slow_line_width;
        m_upper_rebounds[tf_slot].active     = true;
    }

    void CloseUpperTFReboundLine(const int tf_slot, const datetime end_time) {
        if (tf_slot < 0 || tf_slot >= SABAI_MAX_TF_COUNT - 1) return;
        if (!m_upper_rebounds[tf_slot].active) return;
        CObjectHelper::UpsertHLine(m_upper_rebounds[tf_slot].name,
                                   m_upper_rebounds[tf_slot].start_time, end_time,
                                   m_upper_rebounds[tf_slot].price,
                                   m_upper_rebounds[tf_slot].clr,
                                   STYLE_SOLID, m_upper_rebounds[tf_slot].width);
        m_upper_rebounds[tf_slot].active = false;
    }

    void DrawUpperTFPullbackSegment(const int tf_slot,
                                    const ENUM_TIMEFRAMES tf,
                                    const int seg_idx,
                                    const datetime start_time,
                                    const datetime end_time,
                                    const double price) {
        if (tf_slot < 0) return;
        if (start_time <= 0 || end_time <= 0) return;
        string name = SABAI_BIAS_SLOW_PREFIX "UPBS_" +
                      IntegerToString(tf_slot) + "_" +
                      IntegerToString(seg_idx);
        color  clr         = GetTimeframeColor(tf);
        double shift_price = GetShiftedPrice(price, tf, false);
        CObjectHelper::UpsertHLine(name, start_time, end_time, shift_price,
                                   clr, STYLE_SOLID, m_slow_line_width);
    }

    void DrawUpperTFReboundSegment(const int tf_slot,
                                   const ENUM_TIMEFRAMES tf,
                                   const int seg_idx,
                                   const datetime start_time,
                                   const datetime end_time,
                                   const double price) {
        if (tf_slot < 0) return;
        if (start_time <= 0 || end_time <= 0) return;
        string name = SABAI_BIAS_SLOW_PREFIX "URBS_" +
                      IntegerToString(tf_slot) + "_" +
                      IntegerToString(seg_idx);
        color  clr         = GetTimeframeColor(tf);
        double shift_price = GetShiftedPrice(price, tf, true);
        CObjectHelper::UpsertHLine(name, start_time, end_time, shift_price,
                                   clr, STYLE_SOLID, m_slow_line_width);
    }

    void ExtendActiveLines(const datetime current_time) {
        if (m_chart_pullback.active) {
            CObjectHelper::UpsertHLine(m_chart_pullback.name,
                                       m_chart_pullback.start_time, current_time,
                                       m_chart_pullback.price, m_chart_pullback.clr,
                                       STYLE_SOLID, m_chart_pullback.width);
        }
        if (m_chart_rebound.active) {
            CObjectHelper::UpsertHLine(m_chart_rebound.name,
                                       m_chart_rebound.start_time, current_time,
                                       m_chart_rebound.price, m_chart_rebound.clr,
                                       STYLE_SOLID, m_chart_rebound.width);
        }
        for (int i = 0; i < 3; i++) {
            if (m_upper_pullbacks[i].active) {
                CObjectHelper::UpsertHLine(m_upper_pullbacks[i].name,
                                           m_upper_pullbacks[i].start_time, current_time,
                                           m_upper_pullbacks[i].price,
                                           m_upper_pullbacks[i].clr,
                                           STYLE_SOLID, m_upper_pullbacks[i].width);
            }
            if (m_upper_rebounds[i].active) {
                CObjectHelper::UpsertHLine(m_upper_rebounds[i].name,
                                           m_upper_rebounds[i].start_time, current_time,
                                           m_upper_rebounds[i].price,
                                           m_upper_rebounds[i].clr,
                                           STYLE_SOLID, m_upper_rebounds[i].width);
            }
        }
    }
};

#endif
