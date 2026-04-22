#ifndef SABAI_SYSTEM_SLOW_BIAS_DETECTOR_MQH
#define SABAI_SYSTEM_SLOW_BIAS_DETECTOR_MQH

#include "Types.mqh"
#include "SwingDetector.mqh"

struct SlowBiasLineSegment {
    datetime start_time;
    datetime end_time;  // 0 なら未終了（まだ active）
    double   price;
};

class CSlowBiasDetector {
private:
    SlowBiasState m_state;
    bool          m_bias_changed;
    BiasDirection m_prev_direction;

    bool          m_pullback_line_active;
    datetime      m_pullback_line_start_time;
    double        m_pullback_line_price;
    bool          m_pullback_line_changed;

    bool          m_rebound_line_active;
    datetime      m_rebound_line_start_time;
    double        m_rebound_line_price;
    bool          m_rebound_line_changed;

    SlowBiasLineSegment  m_pullback_line_history[];
    int                  m_pullback_line_history_count;
    int                  m_pullback_line_history_capacity;

    SlowBiasLineSegment  m_rebound_line_history[];
    int                  m_rebound_line_history_count;
    int                  m_rebound_line_history_capacity;

    void GrowPullbackLineHistory() {
        if (m_pullback_line_history_count >= m_pullback_line_history_capacity) {
            int new_cap = (m_pullback_line_history_capacity == 0)
                ? 32 : m_pullback_line_history_capacity * 2;
            ArrayResize(m_pullback_line_history, new_cap);
            m_pullback_line_history_capacity = new_cap;
        }
    }

    void GrowReboundLineHistory() {
        if (m_rebound_line_history_count >= m_rebound_line_history_capacity) {
            int new_cap = (m_rebound_line_history_capacity == 0)
                ? 32 : m_rebound_line_history_capacity * 2;
            ArrayResize(m_rebound_line_history, new_cap);
            m_rebound_line_history_capacity = new_cap;
        }
    }

    void AppendPullbackSegment(const datetime start_time, const double price) {
        GrowPullbackLineHistory();
        m_pullback_line_history[m_pullback_line_history_count].start_time = start_time;
        m_pullback_line_history[m_pullback_line_history_count].end_time   = 0;
        m_pullback_line_history[m_pullback_line_history_count].price      = price;
        m_pullback_line_history_count++;
    }

    void ClosePullbackSegment(const datetime end_time) {
        if (m_pullback_line_history_count <= 0) return;
        int last = m_pullback_line_history_count - 1;
        if (m_pullback_line_history[last].end_time == 0) {
            m_pullback_line_history[last].end_time = end_time;
        }
    }

    void AppendReboundSegment(const datetime start_time, const double price) {
        GrowReboundLineHistory();
        m_rebound_line_history[m_rebound_line_history_count].start_time = start_time;
        m_rebound_line_history[m_rebound_line_history_count].end_time   = 0;
        m_rebound_line_history[m_rebound_line_history_count].price      = price;
        m_rebound_line_history_count++;
    }

    void CloseReboundSegment(const datetime end_time) {
        if (m_rebound_line_history_count <= 0) return;
        int last = m_rebound_line_history_count - 1;
        if (m_rebound_line_history[last].end_time == 0) {
            m_rebound_line_history[last].end_time = end_time;
        }
    }

    double GetBreakRefHigh() {
        if (m_state.rebound_high.is_valid && m_state.highest_high.is_valid)
            return MathMax(m_state.rebound_high.price, m_state.highest_high.price);
        if (m_state.rebound_high.is_valid) return m_state.rebound_high.price;
        if (m_state.highest_high.is_valid) return m_state.highest_high.price;
        return 0.0;
    }

    double GetBreakRefLow() {
        if (m_state.pullback_low.is_valid && m_state.lowest_low.is_valid)
            return MathMin(m_state.pullback_low.price, m_state.lowest_low.price);
        if (m_state.pullback_low.is_valid) return m_state.pullback_low.price;
        if (m_state.lowest_low.is_valid)   return m_state.lowest_low.price;
        return 0.0;
    }

    bool HasBreakRefHigh() {
        return m_state.rebound_high.is_valid || m_state.highest_high.is_valid;
    }

    bool HasBreakRefLow() {
        return m_state.pullback_low.is_valid || m_state.lowest_low.is_valid;
    }

public:
    void Init() {
        Reset();
    }

    void Reset() {
        m_state.Reset();
        m_bias_changed   = false;
        m_prev_direction = BIAS_UNKNOWN;
        m_pullback_line_active     = false;
        m_pullback_line_start_time = 0;
        m_pullback_line_price      = 0.0;
        m_pullback_line_changed    = false;
        m_rebound_line_active      = false;
        m_rebound_line_start_time  = 0;
        m_rebound_line_price       = 0.0;
        m_rebound_line_changed     = false;
        ArrayFree(m_pullback_line_history);
        m_pullback_line_history_count    = 0;
        m_pullback_line_history_capacity = 0;
        ArrayFree(m_rebound_line_history);
        m_rebound_line_history_count    = 0;
        m_rebound_line_history_capacity = 0;
    }

    void ProcessBar(CSwingDetector &swing,
                    const MarketPhase current_phase,
                    const double bar_body_high,
                    const double bar_body_low,
                    const datetime bar_time,
                    const BiasDirection quick_direction,
                    const SwingPoint &quick_anchor_low,
                    const SwingPoint &quick_anchor_high) {
        m_prev_direction = m_state.direction;
        m_bias_changed   = false;
        m_pullback_line_changed = false;
        m_rebound_line_changed  = false;

        if (m_state.direction == BIAS_UNKNOWN) {
            if (quick_direction == BIAS_BULLISH && quick_anchor_low.is_valid) {
                m_state.direction    = BIAS_BULLISH;
                m_state.pullback_low = quick_anchor_low;
                StartPullbackLine(quick_anchor_low.time, quick_anchor_low.price);
            } else if (quick_direction == BIAS_BEARISH && quick_anchor_high.is_valid) {
                m_state.direction     = BIAS_BEARISH;
                m_state.rebound_high  = quick_anchor_high;
                StartReboundLine(quick_anchor_high.time, quick_anchor_high.price);
            }
        }

        bool has_break_ref_high = HasBreakRefHigh();
        bool has_break_ref_low  = HasBreakRefLow();
        double break_ref_high   = GetBreakRefHigh();
        double break_ref_low    = GetBreakRefLow();

        bool up_break   = has_break_ref_high && (bar_body_high > break_ref_high);
        bool down_break = has_break_ref_low  && (bar_body_low  < break_ref_low);

        if (up_break && !down_break) {
            OnUpBreak(swing, bar_body_high, bar_time);
        }
        if (down_break && !up_break) {
            OnDownBreak(swing, bar_body_low, bar_time);
        }

        UpdateHighestHighOnSwing(swing, current_phase);
        UpdateLowestLowOnSwing(swing, current_phase);

        if (m_state.direction != m_prev_direction) {
            m_bias_changed = true;
        }
    }

    void OnUpBreak(CSwingDetector &swing,
                   const double bar_body_high,
                   const datetime bar_time) {
        SwingPoint latest_low = swing.GetNearestLow();

        if (m_state.direction == BIAS_BEARISH || m_state.direction == BIAS_UNKNOWN) {
            if (m_state.rebound_high.is_valid && bar_body_high > m_state.rebound_high.price) {
                m_state.direction = BIAS_BULLISH;
                m_state.pullback_low = latest_low;
                m_state.rebound_high.Reset();
                m_state.lowest_low.Reset();

                ClosePullbackLine(bar_time);
                CloseReboundLine(bar_time);
                if (latest_low.is_valid) {
                    StartPullbackLine(latest_low.time, latest_low.price);
                }
                return;
            }
        }

        if (m_state.direction == BIAS_BULLISH) {
            if (m_state.highest_high.is_valid && bar_body_high > m_state.highest_high.price) {
                if (latest_low.is_valid) {
                    ClosePullbackLine(bar_time);
                    m_state.pullback_low = latest_low;
                    StartPullbackLine(latest_low.time, latest_low.price);
                    m_pullback_line_changed = true;
                }
            }
        }
    }

    void OnDownBreak(CSwingDetector &swing,
                     const double bar_body_low,
                     const datetime bar_time) {
        SwingPoint latest_high = swing.GetNearestHigh();

        if (m_state.direction == BIAS_BULLISH || m_state.direction == BIAS_UNKNOWN) {
            if (m_state.pullback_low.is_valid && bar_body_low < m_state.pullback_low.price) {
                m_state.direction = BIAS_BEARISH;
                m_state.rebound_high = latest_high;
                m_state.pullback_low.Reset();
                m_state.highest_high.Reset();

                ClosePullbackLine(bar_time);
                CloseReboundLine(bar_time);
                if (latest_high.is_valid) {
                    StartReboundLine(latest_high.time, latest_high.price);
                }
                return;
            }
        }

        if (m_state.direction == BIAS_BEARISH) {
            if (m_state.lowest_low.is_valid && bar_body_low < m_state.lowest_low.price) {
                if (latest_high.is_valid) {
                    CloseReboundLine(bar_time);
                    m_state.rebound_high = latest_high;
                    StartReboundLine(latest_high.time, latest_high.price);
                    m_rebound_line_changed = true;
                }
            }
        }
    }

    void UpdateHighestHighOnSwing(CSwingDetector &swing,
                                  const MarketPhase current_phase) {
        if (!swing.IsCurrentSwingHigh()) return;
        if (m_state.direction != BIAS_BULLISH) return;

        SwingPoint lh = swing.GetLatestHigh();
        if (!lh.is_valid) return;

        if (current_phase == PHASE_UP_TREND ||
            m_state.direction == BIAS_BULLISH) {
            if (!m_state.highest_high.is_valid) {
                m_state.highest_high = lh;
            } else if (lh.price > m_state.highest_high.price) {
                m_state.highest_high = lh;
            }
        }
    }

    void UpdateLowestLowOnSwing(CSwingDetector &swing,
                                const MarketPhase current_phase) {
        if (!swing.IsCurrentSwingLow()) return;
        if (m_state.direction != BIAS_BEARISH) return;

        SwingPoint ll = swing.GetLatestLow();
        if (!ll.is_valid) return;

        if (current_phase == PHASE_DOWN_TREND ||
            m_state.direction == BIAS_BEARISH) {
            if (!m_state.lowest_low.is_valid) {
                m_state.lowest_low = ll;
            } else if (ll.price < m_state.lowest_low.price) {
                m_state.lowest_low = ll;
            }
        }
    }

    void StartPullbackLine(const datetime start_time, const double price) {
        if (m_pullback_line_active) {
            ClosePullbackSegment(start_time);
        }
        m_pullback_line_active     = true;
        m_pullback_line_start_time = start_time;
        m_pullback_line_price      = price;
        AppendPullbackSegment(start_time, price);
    }

    void ClosePullbackLine(const datetime end_time) {
        if (!m_pullback_line_active) return;
        ClosePullbackSegment(end_time);
        m_pullback_line_active = false;
    }

    void StartReboundLine(const datetime start_time, const double price) {
        if (m_rebound_line_active) {
            CloseReboundSegment(start_time);
        }
        m_rebound_line_active     = true;
        m_rebound_line_start_time = start_time;
        m_rebound_line_price      = price;
        AppendReboundSegment(start_time, price);
    }

    void CloseReboundLine(const datetime end_time) {
        if (!m_rebound_line_active) return;
        CloseReboundSegment(end_time);
        m_rebound_line_active = false;
    }

    SlowBiasState GetState()              { return m_state; }
    BiasDirection GetDirection()           { return m_state.direction; }
    bool          HasBiasChanged()        { return m_bias_changed; }
    BiasDirection GetPrevDirection()       { return m_prev_direction; }

    bool     IsPullbackLineActive()       { return m_pullback_line_active; }
    bool     HasPullbackLineChanged()    { return m_pullback_line_changed; }
    datetime GetPullbackLineStartTime()   { return m_pullback_line_start_time; }
    double   GetPullbackLinePrice()       { return m_pullback_line_price; }

    bool     IsReboundLineActive()        { return m_rebound_line_active; }
    bool     HasReboundLineChanged()     { return m_rebound_line_changed; }
    datetime GetReboundLineStartTime()    { return m_rebound_line_start_time; }
    double   GetReboundLinePrice()        { return m_rebound_line_price; }

    int GetPullbackLineSegmentCount() { return m_pullback_line_history_count; }
    bool GetPullbackLineSegment(const int idx, SlowBiasLineSegment &out) {
        if (idx < 0 || idx >= m_pullback_line_history_count) return false;
        out = m_pullback_line_history[idx];
        return true;
    }

    int GetReboundLineSegmentCount() { return m_rebound_line_history_count; }
    bool GetReboundLineSegment(const int idx, SlowBiasLineSegment &out) {
        if (idx < 0 || idx >= m_rebound_line_history_count) return false;
        out = m_rebound_line_history[idx];
        return true;
    }
};

#endif
