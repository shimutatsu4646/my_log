#ifndef SABAI_SYSTEM_TIMEFRAME_ANALYZER_MQH
#define SABAI_SYSTEM_TIMEFRAME_ANALYZER_MQH

#include "Types.mqh"
#include "SwingDetector.mqh"
#include "MarketPhaseDetector.mqh"
#include "QuickBiasDetector.mqh"
#include "SlowBiasDetector.mqh"
#include "QuickBiasGaze.mqh"

class CTimeframeAnalyzer {
private:
    ENUM_TIMEFRAMES      m_timeframe;
    int                  m_swing_span;

    CSwingDetector       m_swing;
    CMarketPhaseDetector m_phase;
    CQuickBiasDetector   m_quick_bias;
    CSlowBiasDetector    m_slow_bias;
    CQuickBiasGaze       m_gaze;

    TimeframeState       m_state;
    int                  m_bars_processed;

public:
    void Init(const ENUM_TIMEFRAMES tf, const int swing_span) {
        m_timeframe = tf;
        m_swing_span = swing_span;
        m_swing.Init(swing_span);
        m_phase.Init(tf);
        m_quick_bias.Init();
        m_slow_bias.Init();
        m_gaze.Init();
        m_state.Reset();
        m_state.timeframe = tf;
        m_bars_processed = 0;
    }

    void Reset() {
        m_swing.Reset();
        m_phase.Reset();
        m_quick_bias.Reset();
        m_slow_bias.Reset();
        m_gaze.Reset();
        m_state.Reset();
        m_state.timeframe = m_timeframe;
        m_bars_processed = 0;
    }

    void ProcessBar(const int index,
                    const datetime &time[],
                    const double &open[],
                    const double &high[],
                    const double &low[],
                    const double &close[],
                    const int total) {
        double bar_body_high = MathMax(open[index], close[index]);
        double bar_body_low  = MathMin(open[index], close[index]);

        m_swing.ProcessBar(index, time[index],
                           open[index], high[index], low[index], close[index],
                           high, low, total);

        m_phase.ProcessBar(m_swing, bar_body_high, bar_body_low, time[index]);

        m_quick_bias.ProcessBar(m_swing, bar_body_high, bar_body_low,
                                high[index], low[index], time[index]);

        QuickBiasState qbs = m_quick_bias.GetState();
        SwingPoint qb_anchor_low  = qbs.anchor_low;
        SwingPoint qb_anchor_high = qbs.anchor_high;

        m_slow_bias.ProcessBar(m_swing, m_phase.GetCurrentPhase(),
                               bar_body_high, bar_body_low, time[index],
                               qbs.direction, qb_anchor_low, qb_anchor_high);

        m_gaze.ProcessBar(m_swing.IsCurrentSwingHigh(),
                          m_swing.IsCurrentSwingLow(),
                          high[index], low[index],
                          bar_body_high, bar_body_low,
                          time[index]);

        SyncState();
        m_bars_processed++;
    }

    void SyncState() {
        m_state.current_phase = m_phase.GetCurrentPhase();
        m_state.quick_bias    = m_quick_bias.GetState();
        m_state.slow_bias     = m_slow_bias.GetState();

        // active に加えて ended レンジも描画対象として保持する
        int range_count = m_phase.GetAllRangeCount();
        ArrayResize(m_state.active_ranges, range_count);
        for (int i = 0; i < range_count; i++) {
            RangeZone zone;
            if (m_phase.GetRange(i, zone))
                m_state.active_ranges[i] = zone;
        }
    }

    TimeframeState       GetState()          { return m_state; }
    CSwingDetector*      GetSwing()          { return GetPointer(m_swing); }
    CMarketPhaseDetector* GetPhase()         { return GetPointer(m_phase); }
    CQuickBiasDetector*  GetQuickBias()      { return GetPointer(m_quick_bias); }
    CSlowBiasDetector*   GetSlowBias()       { return GetPointer(m_slow_bias); }
    CQuickBiasGaze*      GetGaze()           { return GetPointer(m_gaze); }
    ENUM_TIMEFRAMES      GetTimeframe()      { return m_timeframe; }
    int                  GetSwingSpan()      { return m_swing_span; }
    int                  GetBarsProcessed()  { return m_bars_processed; }
};

#endif
