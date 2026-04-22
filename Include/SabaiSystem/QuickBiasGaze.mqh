#ifndef SABAI_SYSTEM_QUICK_BIAS_GAZE_MQH
#define SABAI_SYSTEM_QUICK_BIAS_GAZE_MQH

#include "Types.mqh"

class CQuickBiasGaze {
private:
    BiasDirection m_direction;

    bool   m_has_quick_bias_low;
    double m_quick_bias_low;
    bool   m_has_quick_bias_high;
    double m_quick_bias_high;

    bool   m_has_latest_swing_high;
    double m_latest_swing_high;
    bool   m_has_latest_swing_low;
    double m_latest_swing_low;

    bool   m_has_confirmed_high;
    double m_confirmed_high;
    bool   m_has_confirmed_low;
    double m_confirmed_low;
    int    m_last_confirmed_type;

    bool   m_has_running_high;
    double m_running_high;
    bool   m_has_running_low;
    double m_running_low;

public:
    void Init() { Reset(); }

    void Reset() {
        m_direction             = BIAS_UNKNOWN;
        m_has_quick_bias_low      = false;
        m_quick_bias_low          = 0.0;
        m_has_quick_bias_high      = false;
        m_quick_bias_high          = 0.0;
        m_has_latest_swing_high = false;
        m_latest_swing_high     = 0.0;
        m_has_latest_swing_low  = false;
        m_latest_swing_low      = 0.0;
        m_has_confirmed_high    = false;
        m_confirmed_high        = 0.0;
        m_has_confirmed_low     = false;
        m_confirmed_low         = 0.0;
        m_last_confirmed_type   = 0;
        m_has_running_high      = false;
        m_running_high          = 0.0;
        m_has_running_low       = false;
        m_running_low           = 0.0;
    }

    void ProcessBar(const bool is_swing_high,
                    const bool is_swing_low,
                    const double bar_high,
                    const double bar_low,
                    const double bar_body_high,
                    const double bar_body_low,
                    const datetime bar_time = 0) {

        if (is_swing_high) {
            m_latest_swing_high = bar_high;
            m_has_latest_swing_high = true;
            if (m_direction == BIAS_BEARISH) {
                if (!m_has_quick_bias_high || bar_high < m_quick_bias_high) {
                    m_quick_bias_high = bar_high;
                    m_has_quick_bias_high = true;
                }
            }
        }
        if (is_swing_low) {
            m_latest_swing_low = bar_low;
            m_has_latest_swing_low = true;
            if (m_direction == BIAS_BULLISH) {
                if (!m_has_quick_bias_low || bar_low > m_quick_bias_low) {
                    m_quick_bias_low = bar_low;
                    m_has_quick_bias_low = true;
                }
            }
        }

        double high_break_ref  = m_has_quick_bias_high ? m_quick_bias_high : m_confirmed_high;
        double low_break_ref = m_has_quick_bias_low ? m_quick_bias_low : m_confirmed_low;
        bool has_high_break_ref  = m_has_quick_bias_high || m_has_confirmed_high;
        bool has_low_break_ref = m_has_quick_bias_low || m_has_confirmed_low;

        bool up_break   = has_high_break_ref  && (bar_body_high > high_break_ref);
        bool down_break = has_low_break_ref && (bar_body_low  < low_break_ref);

        if (up_break && m_has_latest_swing_low) {
            if (!m_has_quick_bias_low || m_latest_swing_low >= m_quick_bias_low) {
                m_quick_bias_low = m_latest_swing_low;
                m_has_quick_bias_low = true;
            }
        }
        if (down_break && m_has_latest_swing_high) {
            if (!m_has_quick_bias_high || m_latest_swing_high <= m_quick_bias_high) {
                m_quick_bias_high = m_latest_swing_high;
                m_has_quick_bias_high = true;
            }
        }

        BiasDirection prev_dir = m_direction;
        if (up_break && !down_break)
            m_direction = BIAS_BULLISH;
        else if (down_break && !up_break)
            m_direction = BIAS_BEARISH;

        if (prev_dir != m_direction) {
            if (m_direction == BIAS_BULLISH) {
                m_has_quick_bias_high = false;
                m_has_running_high = false;
            } else if (m_direction == BIAS_BEARISH) {
                m_has_quick_bias_low = false;
                m_has_running_low  = false;
            }
        }

        if (m_direction == BIAS_BULLISH) {
            if (!m_has_running_high) {
                m_running_high = bar_high;
                m_has_running_high = true;
            } else if (bar_high > m_running_high) {
                m_running_high = bar_high;
            }
        } else if (m_direction == BIAS_BEARISH) {
            if (!m_has_running_low) {
                m_running_low = bar_low;
                m_has_running_low = true;
            } else if (bar_low < m_running_low) {
                m_running_low = bar_low;
            }
        }

        if (is_swing_high && m_last_confirmed_type != 1) {
            m_confirmed_high = bar_high;
            m_has_confirmed_high = true;
            m_last_confirmed_type = 1;
        }
        if (is_swing_low && m_last_confirmed_type != 2) {
            m_confirmed_low = bar_low;
            m_has_confirmed_low = true;
            m_last_confirmed_type = 2;
        }
    }

    BiasDirection GetDirection() { return m_direction; }

    double GetUpper() {
        if (m_direction == BIAS_BULLISH && m_has_running_high)
            return m_running_high;
        if (m_direction == BIAS_BEARISH && m_has_quick_bias_high)
            return m_quick_bias_high;
        return 0.0;
    }

    double GetLower() {
        if (m_direction == BIAS_BULLISH && m_has_quick_bias_low)
            return m_quick_bias_low;
        if (m_direction == BIAS_BEARISH && m_has_running_low)
            return m_running_low;
        return 0.0;
    }

    bool HasValidBounds() {
        if (m_direction == BIAS_BULLISH)
            return m_has_quick_bias_low && m_has_running_high;
        if (m_direction == BIAS_BEARISH)
            return m_has_quick_bias_high && m_has_running_low;
        return false;
    }
};

#endif
