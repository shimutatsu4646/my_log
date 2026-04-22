#ifndef SABAI_SYSTEM_MARKET_PHASE_DETECTOR_MQH
#define SABAI_SYSTEM_MARKET_PHASE_DETECTOR_MQH

#include "Types.mqh"
#include "SwingDetector.mqh"

class CMarketPhaseDetector {
private:
    MarketPhase  m_current_phase;
    ENUM_TIMEFRAMES m_timeframe;

    bool         m_has_higher_low_ready;
    bool         m_has_higher_high_ready;
    bool         m_has_lower_high_ready;
    bool         m_has_lower_low_ready;
    // 「切り上げていない／切り下げていない」(同値を含む) の判定フラグ
    bool         m_has_non_higher_high_ready;
    bool         m_has_non_lower_low_ready;

    RangeZone    m_all_ranges[];
    int          m_range_count;

    bool         m_phase_changed;
    MarketPhase  m_prev_phase;

    int          m_last_range_confirmed_idx;
    bool         m_range_confirmed_event;
    int          m_last_range_ended_idx;
    bool         m_range_ended_event;

    // 同じ swing 起点 (upper_start_time / lower_start_time のペア一致) を持つレンジが
    // 既に存在する場合は新規 push せず -1 を返す。is_active を見ないのは、上限/下限ブレイクで
    // ended になった直後に同一 swing 起点で再 fire されるケース (例: 共有上限ブレイクで
    // 親子同時終了 → トレンド遷移 → 次 bar で swing 状態が動かないまま EnterRange / 範囲条件が
    // 再成立) を重複として吸収するため。価格一致のみで swing 起点が異なるケースは別レンジ扱い。
    int PushRange(const RangeZone &zone) {
        for (int i = 0; i < m_range_count; i++) {
            if (m_all_ranges[i].upper_start_time == zone.upper_start_time &&
                m_all_ranges[i].lower_start_time == zone.lower_start_time) {
                return -1;
            }
        }
        int new_count = m_range_count + 1;
        ArrayResize(m_all_ranges, new_count);
        m_all_ranges[m_range_count] = zone;
        int idx = m_range_count;
        m_range_count = new_count;
        return idx;
    }

    int ActiveRangeCount() {
        int c = 0;
        for (int i = 0; i < m_range_count; i++) {
            if (m_all_ranges[i].is_active) c++;
        }
        return c;
    }

public:
    void Init(const ENUM_TIMEFRAMES tf) {
        m_timeframe = tf;
        Reset();
    }

    void Reset() {
        m_current_phase = PHASE_UNKNOWN;
        m_has_higher_low_ready  = false;
        m_has_higher_high_ready = false;
        m_has_lower_high_ready  = false;
        m_has_lower_low_ready   = false;
        m_has_non_higher_high_ready = false;
        m_has_non_lower_low_ready   = false;
        ArrayFree(m_all_ranges);
        m_range_count = 0;
        m_phase_changed = false;
        m_prev_phase    = PHASE_UNKNOWN;

        m_last_range_confirmed_idx = -1;
        m_range_confirmed_event    = false;
        m_last_range_ended_idx     = -1;
        m_range_ended_event        = false;
    }

    void ProcessBar(CSwingDetector &swing,
                    const double bar_body_high,
                    const double bar_body_low,
                    const datetime bar_time) {
        m_prev_phase    = m_current_phase;
        m_phase_changed = false;
        m_range_confirmed_event = false;
        m_range_ended_event     = false;
        m_last_range_confirmed_idx = -1;
        m_last_range_ended_idx     = -1;

        UpdateReadyFlags(swing);
        EvaluatePhaseTransition(swing, bar_body_high, bar_body_low, bar_time);
        EvaluateRangeBreaks(bar_body_high, bar_body_low, bar_time);

        if (m_current_phase != m_prev_phase) {
            m_phase_changed = true;
        }
    }

    void UpdateReadyFlags(CSwingDetector &swing) {
        if (swing.IsCurrentSwingHigh()) {
            SwingPoint latest = swing.GetLatestHigh();
            SwingPoint prev   = swing.GetPreviousHigh();
            if (latest.is_valid && prev.is_valid) {
                m_has_higher_high_ready     = (latest.body_price >  prev.price);
                m_has_lower_high_ready      = (latest.body_price <  prev.price);
                m_has_non_higher_high_ready = (latest.body_price <= prev.price);
            }
        }

        if (swing.IsCurrentSwingLow()) {
            SwingPoint latest = swing.GetLatestLow();
            SwingPoint prev   = swing.GetPreviousLow();
            if (latest.is_valid && prev.is_valid) {
                m_has_higher_low_ready    = (latest.body_price >  prev.price);
                m_has_lower_low_ready     = (latest.body_price <  prev.price);
                m_has_non_lower_low_ready = (latest.body_price >= prev.price);
            }
        }
    }

    bool IsRangeConditionSatisfied(CSwingDetector &swing) {
        SwingPoint lh = swing.GetLatestHigh();
        SwingPoint ph = swing.GetPreviousHigh();
        SwingPoint ll = swing.GetLatestLow();
        SwingPoint pl = swing.GetPreviousLow();
        if (!lh.is_valid || !ph.is_valid || !ll.is_valid || !pl.is_valid)
            return false;
        // 「切り上げていない」かつ「切り下げていない」をヒゲ基準で判定。
        // 直近高値/安値のヒゲが直前高値/安値を抜けていたら不成立（同値は成立側に含める）。
        if (lh.price >  ph.price) return false;
        if (ll.price <  pl.price) return false;
        return true;
    }

    void EvaluatePhaseTransition(CSwingDetector &swing,
                                 const double bar_body_high,
                                 const double bar_body_low,
                                 const datetime bar_time) {
        switch (m_current_phase) {
            case PHASE_UNKNOWN:
            case PHASE_RANDOM:
                TryTransitionFromRandom(swing, bar_body_high, bar_body_low, bar_time);
                break;
            case PHASE_UP_TREND:
                TryTransitionFromUpTrend(swing, bar_body_high, bar_body_low, bar_time);
                break;
            case PHASE_DOWN_TREND:
                TryTransitionFromDownTrend(swing, bar_body_high, bar_body_low, bar_time);
                break;
            case PHASE_RANGE:
                TryTransitionFromRange(swing, bar_body_high, bar_body_low, bar_time);
                break;
        }
    }

    void TryTransitionFromRandom(CSwingDetector &swing,
                                 const double bar_body_high,
                                 const double bar_body_low,
                                 const datetime bar_time) {
        if (m_has_higher_low_ready && m_has_higher_high_ready) {
            SwingPoint lh = swing.GetLatestHigh();
            if (lh.is_valid && bar_body_high > lh.price) {
                SetPhase(PHASE_UP_TREND, bar_time);
                return;
            }
        }

        if (m_has_lower_high_ready && m_has_lower_low_ready) {
            SwingPoint ll = swing.GetLatestLow();
            if (ll.is_valid && bar_body_low < ll.price) {
                SetPhase(PHASE_DOWN_TREND, bar_time);
                return;
            }
        }

        if (IsRangeConditionSatisfied(swing)) {
            EnterRange(swing, bar_time);
            return;
        }
    }

    void TryTransitionFromUpTrend(CSwingDetector &swing,
                                  const double bar_body_high,
                                  const double bar_body_low,
                                  const datetime bar_time) {
        if (m_has_lower_high_ready && m_has_lower_low_ready) {
            SwingPoint ll = swing.GetLatestLow();
            if (ll.is_valid && bar_body_low < ll.price) {
                EndPhase(bar_time);
                SetPhase(PHASE_DOWN_TREND, bar_time);
                return;
            }
        }

        if (IsRangeConditionSatisfied(swing)) {
            EnterRange(swing, bar_time);
            return;
        }

        // 上昇トレンド終了条件: 直近スイング安値をローソク足実体が下抜け
        // （下降トレンド or レンジへの移行は上で既に判定済み。該当しなければ RANDOM へ）。
        {
            SwingPoint ll = swing.GetLatestLow();
            if (ll.is_valid && bar_body_low < ll.price) {
                EndPhase(bar_time);
                SetPhase(PHASE_RANDOM, bar_time);
                return;
            }
        }
    }

    void TryTransitionFromDownTrend(CSwingDetector &swing,
                                    const double bar_body_high,
                                    const double bar_body_low,
                                    const datetime bar_time) {
        if (m_has_higher_low_ready && m_has_higher_high_ready) {
            SwingPoint lh = swing.GetLatestHigh();
            if (lh.is_valid && bar_body_high > lh.price) {
                EndPhase(bar_time);
                SetPhase(PHASE_UP_TREND, bar_time);
                return;
            }
        }

        if (IsRangeConditionSatisfied(swing)) {
            EnterRange(swing, bar_time);
            return;
        }

        // 下降トレンド終了条件: 直近スイング高値をローソク足実体が上抜け
        // （上昇トレンド or レンジへの移行は上で既に判定済み。該当しなければ RANDOM へ）。
        {
            SwingPoint lh = swing.GetLatestHigh();
            if (lh.is_valid && bar_body_high > lh.price) {
                EndPhase(bar_time);
                SetPhase(PHASE_RANDOM, bar_time);
                return;
            }
        }
    }

    // 親レンジ（最内側の active レンジ）の index を返す。なければ -1。
    int FindInnermostActiveRangeIdx() {
        for (int i = m_range_count - 1; i >= 0; i--) {
            if (m_all_ranges[i].is_active) return i;
        }
        return -1;
    }

    void TryTransitionFromRange(CSwingDetector &swing,
                                const double bar_body_high,
                                const double bar_body_low,
                                const datetime bar_time) {
        // レンジの中でトレンド確定 → 新しいトレンドを重ねる（レンジは残す）。
        // ここでは phase を上書きせず、レンジ中のブレイクはすべて EvaluateRangeBreaks で処理する。

        // ネストしたレンジ（レンジ中に新たなレンジ条件成立）。
        if (!IsRangeConditionSatisfied(swing)) return;

        SwingPoint ph = swing.GetPreviousHigh();
        SwingPoint pl = swing.GetPreviousLow();

        int parent_idx = FindInnermostActiveRangeIdx();
        bool upper_only_wick = false;
        bool lower_only_wick = false;
        bool upper_shared_swing = false;
        bool lower_shared_swing = false;
        if (parent_idx >= 0) {
            RangeZone parent = m_all_ranges[parent_idx];
            upper_only_wick = (ph.price      >  parent.upper_bound) &&
                              (ph.body_price <= parent.upper_bound);
            lower_only_wick = (pl.price      <  parent.lower_bound) &&
                              (pl.body_price >= parent.lower_bound);
            // 「同じ swing 起点」も shared として扱う。子レンジの前回高値/安値が
            // 親と同じ swing 点であれば、同一の上限/下限ラインを共有する。
            upper_shared_swing = (ph.is_valid && ph.time == parent.upper_start_time);
            lower_shared_swing = (pl.is_valid && pl.time == parent.lower_start_time);
        }

        bool upper_shared = upper_only_wick || upper_shared_swing;
        bool lower_shared = lower_only_wick || lower_shared_swing;

        // ケース2: 両側 wick だけ抜け → 親レンジを終了し、通常レンジを追加。
        // same-swing-only の場合は親を閉じない（純粋に境界を共有するのみ）。
        if (parent_idx >= 0 && upper_only_wick && lower_only_wick) {
            m_all_ranges[parent_idx].is_active  = false;
            m_all_ranges[parent_idx].ended_time = bar_time;
            m_last_range_ended_idx = parent_idx;
            m_range_ended_event    = true;
        }

        // 構築するレンジB の境界を決定
        double   new_upper       = ph.price;
        double   new_lower       = pl.price;
        datetime new_upper_start = ph.time;
        datetime new_lower_start = pl.time;
        bool     shares_upper    = false;
        bool     shares_lower    = false;
        int      use_parent_idx  = -1;

        bool case_one_only = (parent_idx >= 0 &&
                              !(upper_only_wick && lower_only_wick) &&
                              (upper_shared || lower_shared));
        if (case_one_only) {
            RangeZone parent = m_all_ranges[parent_idx];
            if (upper_shared) {
                new_upper       = parent.upper_bound;
                new_upper_start = parent.upper_start_time;
                shares_upper    = true;
            }
            if (lower_shared) {
                new_lower       = parent.lower_bound;
                new_lower_start = parent.lower_start_time;
                shares_lower    = true;
            }
            use_parent_idx = parent_idx;
        }

        RangeZone nested;
        nested.Reset();
        nested.upper_bound      = new_upper;
        nested.lower_bound      = new_lower;
        nested.upper_start_time = new_upper_start;
        nested.lower_start_time = new_lower_start;
        nested.confirmed_time   = bar_time;
        nested.ended_time       = 0;
        nested.is_active        = true;
        nested.shares_upper_with_parent = shares_upper;
        nested.shares_lower_with_parent = shares_lower;
        nested.parent_range_idx         = use_parent_idx;
        int idx = PushRange(nested);
        if (idx < 0) return;
        m_last_range_confirmed_idx = idx;
        m_range_confirmed_event    = true;
    }

    // 各 bar で、active な全レンジに対してブレイク判定を行う。
    // ブレイクしたレンジは is_active=false, ended_time=bar_time で保持する（Pop しない）。
    void EvaluateRangeBreaks(const double bar_body_high,
                             const double bar_body_low,
                             const datetime bar_time) {
        if (m_current_phase != PHASE_RANGE) return;
        if (m_range_count <= 0) return;

        for (int i = m_range_count - 1; i >= 0; i--) {
            if (!m_all_ranges[i].is_active) continue;
            bool broke_upper = (bar_body_high > m_all_ranges[i].upper_bound);
            bool broke_lower = (bar_body_low  < m_all_ranges[i].lower_bound);
            if (broke_upper || broke_lower) {
                bool shares_upper = m_all_ranges[i].shares_upper_with_parent;
                bool shares_lower = m_all_ranges[i].shares_lower_with_parent;
                int  parent_idx   = m_all_ranges[i].parent_range_idx;

                m_all_ranges[i].is_active  = false;
                m_all_ranges[i].ended_time = bar_time;
                m_last_range_ended_idx     = i;
                m_range_ended_event        = true;

                // shared 側がブレイクされた場合は親レンジも同時に終了。
                if (parent_idx >= 0 && parent_idx < m_range_count &&
                    m_all_ranges[parent_idx].is_active &&
                    ((shares_upper && broke_upper) || (shares_lower && broke_lower))) {
                    m_all_ranges[parent_idx].is_active  = false;
                    m_all_ranges[parent_idx].ended_time = bar_time;
                    m_last_range_ended_idx              = parent_idx;
                }
            }
        }

        // 最外側（root レンジ = parent_range_idx == -1）までブレイクされた場合、phase を終了する。
        // 複数の root レンジが履歴上存在しうるため、最新の root を参照する。
        if (ActiveRangeCount() == 0) {
            int root_idx = -1;
            for (int i = m_range_count - 1; i >= 0; i--) {
                if (m_all_ranges[i].parent_range_idx == -1) {
                    root_idx = i;
                    break;
                }
            }
            if (root_idx < 0) root_idx = 0;
            bool outermost_broke_upper = (bar_body_high > m_all_ranges[root_idx].upper_bound);
            bool outermost_broke_lower = (bar_body_low  < m_all_ranges[root_idx].lower_bound);
            EndPhase(bar_time);
            if (outermost_broke_upper && m_has_higher_low_ready)
                SetPhase(PHASE_UP_TREND, bar_time);
            else if (outermost_broke_lower && m_has_lower_high_ready)
                SetPhase(PHASE_DOWN_TREND, bar_time);
            else
                SetPhase(PHASE_RANDOM, bar_time);
        }
    }

    void SetPhase(const MarketPhase phase, const datetime t) {
        m_current_phase = phase;
    }

    void EndPhase(const datetime t) {
    }

    void EnterRange(CSwingDetector &swing, const datetime bar_time) {
        SwingPoint ph = swing.GetPreviousHigh();
        SwingPoint pl = swing.GetPreviousLow();
        if (!ph.is_valid || !pl.is_valid) {
            SetPhase(PHASE_RANDOM, bar_time);
            return;
        }

        if (m_current_phase != PHASE_UNKNOWN && m_current_phase != PHASE_RANDOM) {
            EndPhase(bar_time);
        }

        RangeZone zone;
        zone.Reset();
        zone.upper_bound      = ph.price;
        zone.lower_bound      = pl.price;
        zone.upper_start_time = ph.time;
        zone.lower_start_time = pl.time;
        zone.confirmed_time   = bar_time;
        zone.ended_time       = 0;
        zone.is_active        = true;
        int idx = PushRange(zone);
        if (idx < 0) return;
        m_last_range_confirmed_idx = idx;
        m_range_confirmed_event    = true;

        SetPhase(PHASE_RANGE, bar_time);
    }

    MarketPhase    GetCurrentPhase()        { return m_current_phase; }
    bool           HasPhaseChanged()        { return m_phase_changed; }
    MarketPhase    GetPreviousPhase()       { return m_prev_phase; }

    int  GetAllRangeCount()    { return m_range_count; }
    int  GetActiveRangeCount() { return ActiveRangeCount(); }

    // 範囲: 全レンジ（active / ended）
    bool GetRange(const int idx, RangeZone &zone) {
        if (idx < 0 || idx >= m_range_count) return false;
        zone = m_all_ranges[idx];
        return true;
    }

    // 後方互換: active レンジのみを idx で取得
    bool GetActiveRange(const int idx, RangeZone &zone) {
        int cnt = 0;
        for (int i = 0; i < m_range_count; i++) {
            if (!m_all_ranges[i].is_active) continue;
            if (cnt == idx) { zone = m_all_ranges[i]; return true; }
            cnt++;
        }
        return false;
    }

    bool GetTopActiveRange(RangeZone &zone) {
        for (int i = m_range_count - 1; i >= 0; i--) {
            if (m_all_ranges[i].is_active) { zone = m_all_ranges[i]; return true; }
        }
        return false;
    }

    bool HasHigherLowReady()    { return m_has_higher_low_ready; }
    bool HasHigherHighReady()   { return m_has_higher_high_ready; }
    bool HasLowerHighReady()    { return m_has_lower_high_ready; }
    bool HasLowerLowReady()     { return m_has_lower_low_ready; }

    // レンジ イベント
    bool HasRangeConfirmedEvent() { return m_range_confirmed_event; }
    int  GetLastRangeConfirmedIdx() { return m_last_range_confirmed_idx; }
    bool HasRangeEndedEvent()     { return m_range_ended_event; }
    int  GetLastRangeEndedIdx()   { return m_last_range_ended_idx; }
};

#endif
