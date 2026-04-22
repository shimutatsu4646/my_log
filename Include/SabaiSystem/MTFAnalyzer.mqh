#ifndef SABAI_SYSTEM_MTF_ANALYZER_MQH
#define SABAI_SYSTEM_MTF_ANALYZER_MQH

#include "Types.mqh"
#include "TimeframeAnalyzer.mqh"

class CMTFAnalyzer {
private:
    CTimeframeAnalyzer m_analyzers[SABAI_MAX_TF_COUNT];
    int                m_swing_span;
    int                m_bars_to_lookback;
    ENUM_TIMEFRAMES    m_chart_tf;
    int                m_tf_count;

    ENUM_TIMEFRAMES GetTimeframeForSlot(const int slot) {
        return GetTimeframeByIndex(slot);
    }

    int EstimateBarsNeeded(const ENUM_TIMEFRAMES tf) {
        return m_bars_to_lookback + m_swing_span * 4;
    }

    bool AnalyzeSingleTF(const int slot) {
        ENUM_TIMEFRAMES tf = GetTimeframeForSlot(slot);
        int bars_needed = EstimateBarsNeeded(tf);

        datetime time[];
        double   open[];
        double   high[];
        double   low[];
        double   close[];
        ArraySetAsSeries(time,  false);
        ArraySetAsSeries(open,  false);
        ArraySetAsSeries(high,  false);
        ArraySetAsSeries(low,   false);
        ArraySetAsSeries(close, false);

        int copied_t = CopyTime(_Symbol,  tf, 0, bars_needed, time);
        int copied_o = CopyOpen(_Symbol,  tf, 0, bars_needed, open);
        int copied_h = CopyHigh(_Symbol,  tf, 0, bars_needed, high);
        int copied_l = CopyLow(_Symbol,   tf, 0, bars_needed, low);
        int copied_c = CopyClose(_Symbol, tf, 0, bars_needed, close);

        int total = MathMin(copied_t, MathMin(copied_o, MathMin(copied_h, MathMin(copied_l, copied_c))));
        if (total < m_swing_span * 2 + 1) return false;

        m_analyzers[slot].Reset();
        m_analyzers[slot].Init(tf, m_swing_span);

        // 末尾 swing_span 本もレンジブレイク等の判定対象に含めるため total まで回す。
        // スイング確定は DetectSwingHigh/Low 内のガードで右側 swing_span 本未満なら成立しない。
        int start_idx = m_swing_span;
        int end_idx   = total;
        for (int i = start_idx; i < end_idx; i++) {
            m_analyzers[slot].ProcessBar(i, time, open, high, low, close, total);
        }

        return true;
    }

public:
    void Init(const int swing_span, const int bars_to_lookback,
              const ENUM_TIMEFRAMES chart_tf = PERIOD_H4) {
        m_swing_span       = MathMax(1, swing_span);
        m_bars_to_lookback = MathMax(1, bars_to_lookback);
        m_chart_tf         = chart_tf;
        m_tf_count         = GetTFCount(chart_tf);

        for (int i = 0; i < m_tf_count; i++) {
            m_analyzers[i].Init(GetTimeframeForSlot(i), m_swing_span);
        }
    }

    bool Analyze() {
        bool all_ok = true;
        for (int i = 0; i < m_tf_count; i++) {
            if (!AnalyzeSingleTF(i))
                all_ok = false;
        }
        return all_ok;
    }

    bool AnalyzeUpperTFsOnly() {
        bool ok = true;
        for (int i = 0; i < m_tf_count - 1; i++) {
            if (!AnalyzeSingleTF(i))
                ok = false;
        }
        return ok;
    }

    TimeframeState GetState(const int slot) {
        return m_analyzers[slot].GetState();
    }

    CTimeframeAnalyzer* GetAnalyzer(const int slot) {
        return GetPointer(m_analyzers[slot]);
    }

    int GetChartSlot()                  { return m_tf_count - 1; }
    ENUM_TIMEFRAMES GetChartTF()        { return m_chart_tf; }
    int             GetSwingSpan()      { return m_swing_span; }
    int             GetBarsToLookback() { return m_bars_to_lookback; }
    int             GetTotalTFCount()   { return m_tf_count; }
    int             GetUpperTFCount()   { return m_tf_count - 1; }
};

#endif
