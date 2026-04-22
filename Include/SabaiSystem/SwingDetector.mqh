#ifndef SABAI_SYSTEM_SWING_DETECTOR_MQH
#define SABAI_SYSTEM_SWING_DETECTOR_MQH

#include "Types.mqh"

class CSwingDetector {
private:
    int        m_swing_span;

    SwingPoint m_latest_high;
    SwingPoint m_latest_low;
    SwingPoint m_previous_high;
    SwingPoint m_previous_low;
    SwingPoint m_nearest_high;
    SwingPoint m_nearest_low;

    SwingType  m_last_confirmed_type;

    SwingPoint m_history[];
    int        m_history_count;
    int        m_history_capacity;

    bool       m_current_is_swing_high;
    bool       m_current_is_swing_low;

    void GrowHistory() {
        if (m_history_count >= m_history_capacity) {
            int new_cap = (m_history_capacity == 0) ? 256 : m_history_capacity * 2;
            ArrayResize(m_history, new_cap);
            m_history_capacity = new_cap;
        }
    }

    void AppendHistory(const SwingPoint &pt) {
        GrowHistory();
        m_history[m_history_count] = pt;
        m_history_count++;
    }

public:
    void Init(const int swing_span) {
        m_swing_span = MathMax(1, swing_span);
        Reset();
    }

    void Reset() {
        m_latest_high.Reset();
        m_latest_low.Reset();
        m_previous_high.Reset();
        m_previous_low.Reset();
        m_nearest_high.Reset();
        m_nearest_low.Reset();
        m_last_confirmed_type = SWING_NONE;
        m_history_count    = 0;
        m_history_capacity = 0;
        ArrayFree(m_history);
        m_current_is_swing_high = false;
        m_current_is_swing_low  = false;
    }

    bool DetectSwingHigh(const int index,
                         const double &high[],
                         const int total) {
        if (index < m_swing_span || index + m_swing_span >= total)
            return false;
        for (int j = 1; j <= m_swing_span; j++) {
            if (high[index] <= high[index - j] || high[index] <= high[index + j])
                return false;
        }
        return true;
    }

    bool DetectSwingLow(const int index,
                        const double &low[],
                        const int total) {
        if (index < m_swing_span || index + m_swing_span >= total)
            return false;
        for (int j = 1; j <= m_swing_span; j++) {
            if (low[index] >= low[index - j] || low[index] >= low[index + j])
                return false;
        }
        return true;
    }

    void ProcessBar(const int index,
                    const datetime bar_time,
                    const double bar_open,
                    const double bar_high,
                    const double bar_low,
                    const double bar_close,
                    const double &high_arr[],
                    const double &low_arr[],
                    const int total) {
        m_current_is_swing_high = DetectSwingHigh(index, high_arr, total);
        m_current_is_swing_low  = DetectSwingLow(index, low_arr, total);

        if (m_current_is_swing_high) {
            OnSwingHighConfirmed(index, bar_time, bar_open, bar_high, bar_close);
        }
        if (m_current_is_swing_low) {
            OnSwingLowConfirmed(index, bar_time, bar_open, bar_low, bar_close);
        }
    }

    void OnSwingHighConfirmed(const int index,
                              const datetime bar_time,
                              const double bar_open,
                              const double bar_high,
                              const double bar_close) {
        SwingPoint pt;
        pt.price      = bar_high;
        pt.body_price = MathMax(bar_open, bar_close);
        pt.time       = bar_time;
        pt.bar_index  = index;
        pt.is_valid   = true;

        m_nearest_high = pt;

        if (m_last_confirmed_type == SWING_HIGH) {
            if (pt.price > m_latest_high.price) {
                m_latest_high = pt;
                if (m_history_count > 0)
                    m_history[m_history_count - 1] = pt;
            }
            return;
        }

        if (m_latest_high.is_valid) {
            m_previous_high = m_latest_high;
        }
        m_latest_high = pt;
        m_last_confirmed_type = SWING_HIGH;
        AppendHistory(pt);
    }

    void OnSwingLowConfirmed(const int index,
                             const datetime bar_time,
                             const double bar_open,
                             const double bar_low,
                             const double bar_close) {
        SwingPoint pt;
        pt.price      = bar_low;
        pt.body_price = MathMin(bar_open, bar_close);
        pt.time       = bar_time;
        pt.bar_index  = index;
        pt.is_valid   = true;

        m_nearest_low = pt;

        if (m_last_confirmed_type == SWING_LOW) {
            if (pt.price < m_latest_low.price) {
                m_latest_low = pt;
                if (m_history_count > 0)
                    m_history[m_history_count - 1] = pt;
            }
            return;
        }

        if (m_latest_low.is_valid) {
            m_previous_low = m_latest_low;
        }
        m_latest_low = pt;
        m_last_confirmed_type = SWING_LOW;
        AppendHistory(pt);
    }

    bool      IsCurrentSwingHigh()    { return m_current_is_swing_high; }
    bool      IsCurrentSwingLow()     { return m_current_is_swing_low; }

    SwingPoint GetLatestHigh()        { return m_latest_high; }
    SwingPoint GetLatestLow()         { return m_latest_low; }
    SwingPoint GetPreviousHigh()      { return m_previous_high; }
    SwingPoint GetPreviousLow()       { return m_previous_low; }
    SwingPoint GetNearestHigh()       { return m_nearest_high; }
    SwingPoint GetNearestLow()        { return m_nearest_low; }
    SwingType  GetLastConfirmedType() { return m_last_confirmed_type; }

    SwingPoint GetStartingHigh(const SwingPoint &ref_low) {
        SwingPoint empty;
        empty.Reset();
        if (!ref_low.is_valid || m_history_count < 2)
            return empty;
        for (int i = m_history_count - 1; i >= 0; i--) {
            if (m_history[i].time == ref_low.time)
                continue;
            if (m_history[i].time < ref_low.time &&
                m_history[i].price > ref_low.price) {
                return m_history[i];
            }
        }
        return empty;
    }

    SwingPoint GetStartingLow(const SwingPoint &ref_high) {
        SwingPoint empty;
        empty.Reset();
        if (!ref_high.is_valid || m_history_count < 2)
            return empty;
        for (int i = m_history_count - 1; i >= 0; i--) {
            if (m_history[i].time == ref_high.time)
                continue;
            if (m_history[i].time < ref_high.time &&
                m_history[i].price < ref_high.price) {
                return m_history[i];
            }
        }
        return empty;
    }

    int        GetHistoryCount()      { return m_history_count; }
    SwingPoint GetHistoryAt(int i)    { return m_history[i]; }
    int        GetSwingSpan()         { return m_swing_span; }
};

#endif
