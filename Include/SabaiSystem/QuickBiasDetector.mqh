#ifndef SABAI_SYSTEM_QUICK_BIAS_DETECTOR_MQH
#define SABAI_SYSTEM_QUICK_BIAS_DETECTOR_MQH

#include "Types.mqh"
#include "SwingDetector.mqh"

class CQuickBiasDetector {
private:
    QuickBiasState m_state;
    bool           m_bias_changed;
    BiasDirection  m_prev_direction;

public:
    void Init() {
        Reset();
    }

    void Reset() {
        m_state.Reset();
        m_bias_changed  = false;
        m_prev_direction = BIAS_UNKNOWN;
    }

    void ProcessBar(CSwingDetector &swing,
                    const double bar_body_high,
                    const double bar_body_low,
                    const double bar_high,
                    const double bar_low,
                    const datetime bar_time) {
        m_prev_direction = m_state.direction;
        m_bias_changed   = false;

        SwingPoint latest_high = swing.GetLatestHigh();
        SwingPoint latest_low  = swing.GetLatestLow();

        bool up_break   = latest_high.is_valid && (bar_body_high > latest_high.price);
        bool down_break = latest_low.is_valid  && (bar_body_low  < latest_low.price);

        if (m_state.direction == BIAS_UNKNOWN) {
            if (up_break && !down_break) {
                SetBullish(swing, bar_time);
            } else if (down_break && !up_break) {
                SetBearish(swing, bar_time);
            }
        } else if (m_state.direction == BIAS_BULLISH) {
            if (down_break) {
                if (m_state.anchor_low.is_valid && bar_body_low < m_state.anchor_low.price) {
                    SetBearish(swing, bar_time);
                }
            }
            UpdateBullishTracking(swing, bar_body_high, bar_high, bar_low);
        } else if (m_state.direction == BIAS_BEARISH) {
            if (up_break) {
                if (m_state.anchor_high.is_valid && bar_body_high > m_state.anchor_high.price) {
                    SetBullish(swing, bar_time);
                }
            }
            UpdateBearishTracking(swing, bar_body_low, bar_high, bar_low);
        }

        if (m_state.direction != m_prev_direction) {
            m_bias_changed = true;
        }
    }

    void SetBullish(CSwingDetector &swing, const datetime bar_time) {
        m_state.direction = BIAS_BULLISH;
        m_state.anchor_low  = swing.GetLatestLow();
        m_state.anchor_high.Reset();
        m_state.tracking_high = swing.GetLatestHigh();
        m_state.tracking_low.Reset();
    }

    void SetBearish(CSwingDetector &swing, const datetime bar_time) {
        m_state.direction = BIAS_BEARISH;
        m_state.anchor_high = swing.GetLatestHigh();
        m_state.anchor_low.Reset();
        m_state.tracking_low  = swing.GetLatestLow();
        m_state.tracking_high.Reset();
    }

    void UpdateBullishTracking(CSwingDetector &swing,
                               const double bar_body_high,
                               const double bar_high,
                               const double bar_low) {
        if (m_state.tracking_high.is_valid && bar_body_high > m_state.tracking_high.price) {
            SwingPoint lh = swing.GetLatestHigh();
            if (lh.is_valid && lh.price > m_state.tracking_high.price) {
                m_state.tracking_high = lh;
            }
        }
        if (swing.IsCurrentSwingHigh()) {
            SwingPoint lh = swing.GetLatestHigh();
            if (!m_state.tracking_high.is_valid || lh.price > m_state.tracking_high.price) {
                m_state.tracking_high = lh;
            }
        }
        m_state.anchor_low = swing.GetLatestLow();
    }

    void UpdateBearishTracking(CSwingDetector &swing,
                               const double bar_body_low,
                               const double bar_high,
                               const double bar_low) {
        if (m_state.tracking_low.is_valid && bar_body_low < m_state.tracking_low.price) {
            SwingPoint ll = swing.GetLatestLow();
            if (ll.is_valid && ll.price < m_state.tracking_low.price) {
                m_state.tracking_low = ll;
            }
        }
        if (swing.IsCurrentSwingLow()) {
            SwingPoint ll = swing.GetLatestLow();
            if (!m_state.tracking_low.is_valid || ll.price < m_state.tracking_low.price) {
                m_state.tracking_low = ll;
            }
        }
        m_state.anchor_high = swing.GetLatestHigh();
    }

    QuickBiasState GetState()         { return m_state; }
    BiasDirection  GetDirection()     { return m_state.direction; }
    bool           HasBiasChanged()  { return m_bias_changed; }
    BiasDirection  GetPrevDirection() { return m_prev_direction; }

};

#endif
