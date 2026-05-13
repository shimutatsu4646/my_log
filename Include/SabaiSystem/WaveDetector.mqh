#ifndef SABAI_SYSTEM_WAVE_DETECTOR_MQH
#define SABAI_SYSTEM_WAVE_DETECTOR_MQH

#include "Types.mqh"
#include "SwingDetector.mqh"
#include "MarketPhaseDetector.mqh"

struct WaveSegment {
    SwingPoint start;
    SwingPoint end;
    bool       is_valid;

    void Reset() {
        start.Reset();
        end.Reset();
        is_valid = false;
    }
};

// 個別の波。波番号は 1, 2, 3, 4, 5, ... と連続する。
// 奇数=推進波、偶数=調整波。group_id は当該グループのトレンド確定 bar 時刻で固定し、
// 描画オブジェクト名のキーに使う。
struct Wave {
    int          wave_no;
    datetime     group_id;
    MarketPhase  group_dir;
    WaveSegment  segment;

    void Reset() {
        wave_no   = 0;
        group_id  = 0;
        group_dir = PHASE_UNKNOWN;
        segment.Reset();
    }
};

// system_doc.md L87-141 で定義される第1〜3波、および同一 PHASE_UP/DOWN_TREND 中に
// 「継続確定」したときに追加される第x波・第y波を管理する。
//
// グループの寿命:
//   - PHASE が UP/DOWN_TREND に新規遷移 → グループ開始、波 1/2/3 を生成
//   - 同一 PHASE 中に「継続確定」条件が満たされる → 波 4/5（または 6/7 …）を追加
//   - PHASE が UP/DOWN_TREND から外れる → グループ終了、波番号は次の新規トレンドで 1 に戻る
//
// 推進波（奇数波）の終点トラッキング（第3波と同じ要領）:
//   A) running_bar_extreme: 最初の同方向スイング確定までローソク高/安値で延伸
//   B) swing-tracking: 同方向スイング確定で end を最新スイングに同期
//   C) 反対方向スイング確定 / PHASE 終了 で freeze
class CWaveDetector {
private:
    Wave m_waves[];
    int  m_wave_count;
    int  m_wave_capacity;

    bool         m_group_active;
    datetime     m_group_id;
    MarketPhase  m_group_dir;
    int          m_last_wave_no;

    int          m_tracking_wave_idx;     // m_waves 内で end を追っている波のインデックス（-1 で無効）
    bool         m_tracking;              // 推進波の end 更新が有効か
    bool         m_running_bar_extreme;   // ローソク高/安値ベースの延伸モードか

    void GrowWaves() {
        if (m_wave_count >= m_wave_capacity) {
            int new_cap = (m_wave_capacity == 0) ? 64 : m_wave_capacity * 2;
            ArrayResize(m_waves, new_cap);
            m_wave_capacity = new_cap;
        }
    }

    int AppendWave(const Wave &w) {
        GrowWaves();
        m_waves[m_wave_count] = w;
        int idx = m_wave_count;
        m_wave_count++;
        return idx;
    }

    void MakeBarPoint(SwingPoint &pt,
                      const double price,
                      const datetime bar_time) {
        pt.price      = price;
        pt.body_price = price;
        pt.time       = bar_time;
        pt.bar_index  = -1;
        pt.is_valid   = true;
    }

    // latest / previous の 2 候補から time < ref_time を満たす「最も新しい
    // (= ref_time に最も近い)」swing を返す。両方該当しなければ invalid を返す。
    //
    // 同種 swing は SwingDetector 仕様上 latest が previous より新しい時刻になることが
    // 保証されているので、latest を先に評価すれば十分。
    //
    // 用途: spec L115/120/128/132 の「第◯波の起点の直前にある〇〇」判定。
    // 例: 上昇トレンド確定時、wave 2 起点は「第3波の起点(=latest_low)の直前にある swing high」。
    // 通常は latest_high が該当するが、レンジ中に latest_low より後で swing high が
    // 形成されている場合（latest_high.time > latest_low.time）は previous_high を採用する。
    SwingPoint PickSwingBefore(const SwingPoint &latest,
                               const SwingPoint &previous,
                               const datetime ref_time) {
        if (latest.is_valid   && latest.time   < ref_time) return latest;
        if (previous.is_valid && previous.time < ref_time) return previous;
        SwingPoint empty;
        empty.Reset();
        return empty;
    }

    void UpdateTrackingWaveFromBar(CSwingDetector &swing,
                                   const double bar_high,
                                   const double bar_low,
                                   const datetime bar_time) {
        if (!m_tracking) return;
        if (m_tracking_wave_idx < 0 || m_tracking_wave_idx >= m_wave_count) return;

        MarketPhase dir = m_waves[m_tracking_wave_idx].group_dir;

        if (dir == PHASE_UP_TREND) {
            if (m_running_bar_extreme) {
                if (swing.IsCurrentSwingHigh()) {
                    SwingPoint lh = swing.GetLatestHigh();
                    if (lh.is_valid) m_waves[m_tracking_wave_idx].segment.end = lh;
                    m_running_bar_extreme = false;
                    return;
                }
                if (bar_high > m_waves[m_tracking_wave_idx].segment.end.price) {
                    SwingPoint w_end;
                    MakeBarPoint(w_end, bar_high, bar_time);
                    m_waves[m_tracking_wave_idx].segment.end = w_end;
                }
            } else {
                if (swing.IsCurrentSwingHigh()) {
                    SwingPoint lh = swing.GetLatestHigh();
                    if (lh.is_valid) m_waves[m_tracking_wave_idx].segment.end = lh;
                    return;
                }
                if (swing.IsCurrentSwingLow()) {
                    m_tracking = false;
                    return;
                }
            }
        } else if (dir == PHASE_DOWN_TREND) {
            if (m_running_bar_extreme) {
                if (swing.IsCurrentSwingLow()) {
                    SwingPoint ll = swing.GetLatestLow();
                    if (ll.is_valid) m_waves[m_tracking_wave_idx].segment.end = ll;
                    m_running_bar_extreme = false;
                    return;
                }
                if (bar_low < m_waves[m_tracking_wave_idx].segment.end.price) {
                    SwingPoint w_end;
                    MakeBarPoint(w_end, bar_low, bar_time);
                    m_waves[m_tracking_wave_idx].segment.end = w_end;
                }
            } else {
                if (swing.IsCurrentSwingLow()) {
                    SwingPoint ll = swing.GetLatestLow();
                    if (ll.is_valid) m_waves[m_tracking_wave_idx].segment.end = ll;
                    return;
                }
                if (swing.IsCurrentSwingHigh()) {
                    m_tracking = false;
                    return;
                }
            }
        }
    }

    // 新グループ開始。wave 3 → wave 2 → wave 1 の順に append する。
    // wave 2 / wave 1 の起点は spec 改訂後の「直前にある swing」ルールで決定する。
    void StartNewGroup(const SwingPoint &snap_lh,
                       const SwingPoint &snap_ll,
                       const SwingPoint &snap_ph,
                       const SwingPoint &snap_pl,
                       const MarketPhase new_phase,
                       const datetime bar_time,
                       const double bar_high,
                       const double bar_low) {
        if (new_phase != PHASE_UP_TREND && new_phase != PHASE_DOWN_TREND) return;

        m_group_active = true;
        m_group_id     = bar_time;
        m_group_dir    = new_phase;
        m_last_wave_no = 0;
        m_tracking_wave_idx = -1;
        m_tracking            = false;
        m_running_bar_extreme = false;

        if (new_phase == PHASE_UP_TREND) {
            // wave3 が成立しない (直近安値が無い) と他の波も意味を成さない
            if (!snap_ll.is_valid) return;

            // wave 3 (推進、running tracking): 直近安値 → ローソク高値
            Wave w3; w3.Reset();
            w3.wave_no  = 3;
            w3.group_id = m_group_id;
            w3.group_dir = m_group_dir;
            w3.segment.start = snap_ll;
            SwingPoint w3_end;
            MakeBarPoint(w3_end, bar_high, bar_time);
            w3.segment.end      = w3_end;
            w3.segment.is_valid = true;
            int w3_idx = AppendWave(w3);
            m_tracking_wave_idx = w3_idx;
            m_tracking            = true;
            m_running_bar_extreme = true;
            m_last_wave_no        = 3;

            // wave 2 (調整): 第3波の起点(=snap_ll)の直前にあるスイングハイ → 第3波の起点
            SwingPoint w2_start = PickSwingBefore(snap_lh, snap_ph, snap_ll.time);
            if (!w2_start.is_valid) return;   // wave 2 / wave 1 は描けない、wave 3 のみで終了

            Wave w2; w2.Reset();
            w2.wave_no  = 2;
            w2.group_id = m_group_id;
            w2.group_dir = m_group_dir;
            w2.segment.start    = w2_start;
            w2.segment.end      = snap_ll;
            w2.segment.is_valid = true;
            AppendWave(w2);

            // wave 1 (推進、固定): 第2波の起点の直前にあるスイングロー → 第2波の起点
            SwingPoint w1_start = PickSwingBefore(snap_ll, snap_pl, w2_start.time);
            if (!w1_start.is_valid) return;

            Wave w1; w1.Reset();
            w1.wave_no  = 1;
            w1.group_id = m_group_id;
            w1.group_dir = m_group_dir;
            w1.segment.start    = w1_start;
            w1.segment.end      = w2_start;
            w1.segment.is_valid = true;
            AppendWave(w1);
        } else {
            // PHASE_DOWN_TREND（鏡像）
            if (!snap_lh.is_valid) return;

            // wave 3: 直近高値 → ローソク安値
            Wave w3; w3.Reset();
            w3.wave_no  = 3;
            w3.group_id = m_group_id;
            w3.group_dir = m_group_dir;
            w3.segment.start = snap_lh;
            SwingPoint w3_end;
            MakeBarPoint(w3_end, bar_low, bar_time);
            w3.segment.end      = w3_end;
            w3.segment.is_valid = true;
            int w3_idx = AppendWave(w3);
            m_tracking_wave_idx = w3_idx;
            m_tracking            = true;
            m_running_bar_extreme = true;
            m_last_wave_no        = 3;

            // wave 2: 第3波の起点(=snap_lh)の直前にあるスイングロー → 第3波の起点
            SwingPoint w2_start = PickSwingBefore(snap_ll, snap_pl, snap_lh.time);
            if (!w2_start.is_valid) return;

            Wave w2; w2.Reset();
            w2.wave_no  = 2;
            w2.group_id = m_group_id;
            w2.group_dir = m_group_dir;
            w2.segment.start    = w2_start;
            w2.segment.end      = snap_lh;
            w2.segment.is_valid = true;
            AppendWave(w2);

            // wave 1: 第2波の起点の直前にあるスイングハイ → 第2波の起点
            SwingPoint w1_start = PickSwingBefore(snap_lh, snap_ph, w2_start.time);
            if (!w1_start.is_valid) return;

            Wave w1; w1.Reset();
            w1.wave_no  = 1;
            w1.group_id = m_group_id;
            w1.group_dir = m_group_dir;
            w1.segment.start    = w1_start;
            w1.segment.end      = w2_start;
            w1.segment.is_valid = true;
            AppendWave(w1);
        }
    }

    void EndGroup() {
        m_group_active = false;
        m_tracking            = false;
        m_running_bar_extreme = false;
        m_tracking_wave_idx   = -1;
        // m_waves[] はそのまま残す（描画継続のため）
    }

    // 継続確定で偶数(調整)+奇数(推進) の 2 本を追加。
    // 起点/終点は spec L115/120/128/132 改訂後の「直前にある swing」ルールに準拠。
    // - 偶数波 start: 「奇数波 start (= snap_ll / snap_lh) の直前にある反対種 swing」
    //                snapshot の latest / previous を時間比較して選択。
    // - 奇数波 start: 第3波と同じ要領 (= snap_ll / snap_lh)。
    void AddContinuationWaves(const SwingPoint &snap_lh,
                              const SwingPoint &snap_ll,
                              const SwingPoint &snap_ph,
                              const SwingPoint &snap_pl,
                              const MarketPhase dir,
                              const datetime bar_time,
                              const double bar_high,
                              const double bar_low) {
        if (!m_group_active) return;

        if (dir == PHASE_UP_TREND) {
            if (!snap_ll.is_valid) return;

            SwingPoint even_start = PickSwingBefore(snap_lh, snap_ph, snap_ll.time);
            if (!even_start.is_valid) return;   // 偶数波が描けないなら奇数波も追加しない

            int even_no = m_last_wave_no + 1;
            int odd_no  = m_last_wave_no + 2;

            // 偶数波（調整、第2波と同じ要領）
            Wave we; we.Reset();
            we.wave_no  = even_no;
            we.group_id = m_group_id;
            we.group_dir = dir;
            we.segment.start    = even_start;
            we.segment.end      = snap_ll;
            we.segment.is_valid = true;
            AppendWave(we);

            // 奇数波（推進、第3波と同じ要領 / running tracking）
            Wave wo; wo.Reset();
            wo.wave_no  = odd_no;
            wo.group_id = m_group_id;
            wo.group_dir = dir;
            wo.segment.start = snap_ll;
            SwingPoint wo_end;
            MakeBarPoint(wo_end, bar_high, bar_time);
            wo.segment.end      = wo_end;
            wo.segment.is_valid = true;
            int wo_idx = AppendWave(wo);

            m_last_wave_no      = odd_no;
            m_tracking_wave_idx = wo_idx;
            m_tracking            = true;
            m_running_bar_extreme = true;
        } else if (dir == PHASE_DOWN_TREND) {
            if (!snap_lh.is_valid) return;

            SwingPoint even_start = PickSwingBefore(snap_ll, snap_pl, snap_lh.time);
            if (!even_start.is_valid) return;

            int even_no = m_last_wave_no + 1;
            int odd_no  = m_last_wave_no + 2;

            Wave we; we.Reset();
            we.wave_no  = even_no;
            we.group_id = m_group_id;
            we.group_dir = dir;
            we.segment.start    = even_start;
            we.segment.end      = snap_lh;
            we.segment.is_valid = true;
            AppendWave(we);

            Wave wo; wo.Reset();
            wo.wave_no  = odd_no;
            wo.group_id = m_group_id;
            wo.group_dir = dir;
            wo.segment.start = snap_lh;
            SwingPoint wo_end;
            MakeBarPoint(wo_end, bar_low, bar_time);
            wo.segment.end      = wo_end;
            wo.segment.is_valid = true;
            int wo_idx = AppendWave(wo);

            m_last_wave_no      = odd_no;
            m_tracking_wave_idx = wo_idx;
            m_tracking            = true;
            m_running_bar_extreme = true;
        }
    }

public:
    void Init() {
        Reset();
    }

    void Reset() {
        ArrayFree(m_waves);
        m_wave_count    = 0;
        m_wave_capacity = 0;
        m_group_active        = false;
        m_group_id            = 0;
        m_group_dir           = PHASE_UNKNOWN;
        m_last_wave_no        = 0;
        m_tracking_wave_idx   = -1;
        m_tracking            = false;
        m_running_bar_extreme = false;
    }

    // ProcessBar 内で m_swing.ProcessBar 前にスナップショットされた直近・直前スイング点を渡す。
    // bar_body_high/low は継続確定条件（ローソク実体ベース判定）で使用。
    void OnBar(CSwingDetector &swing,
               CMarketPhaseDetector &phase,
               const SwingPoint &snap_lh,
               const SwingPoint &snap_ll,
               const SwingPoint &snap_ph,
               const SwingPoint &snap_pl,
               const double bar_high,
               const double bar_low,
               const double bar_body_high,
               const double bar_body_low,
               const datetime bar_time) {
        // Step 1: 既存 tracking 波の end を当該バーで更新
        UpdateTrackingWaveFromBar(swing, bar_high, bar_low, bar_time);

        // Step 2: PHASE 遷移ハンドリング（新規グループ作成 / グループ終了 / 反転）
        if (phase.HasPhaseChanged()) {
            MarketPhase newp = phase.GetCurrentPhase();
            MarketPhase oldp = phase.GetPreviousPhase();
            bool old_trend = (oldp == PHASE_UP_TREND || oldp == PHASE_DOWN_TREND);
            bool new_trend = (newp == PHASE_UP_TREND || newp == PHASE_DOWN_TREND);

            if (old_trend && !new_trend) {
                EndGroup();
            } else if (!old_trend && new_trend) {
                StartNewGroup(snap_lh, snap_ll, snap_ph, snap_pl,
                              newp, bar_time, bar_high, bar_low);
            } else if (old_trend && new_trend) {
                // reversal
                EndGroup();
                StartNewGroup(snap_lh, snap_ll, snap_ph, snap_pl,
                              newp, bar_time, bar_high, bar_low);
            }
        }

        // Step 3: 同一グループ中の「継続確定」チェック
        //   spec L55/L60 と同じ条件: higher/lower-ready + 実体ブレイク
        //   かつ前回の推進波が freeze 済み (!m_tracking) のときのみ発火
        if (!m_group_active) return;
        if (phase.GetCurrentPhase() != m_group_dir) return;
        if (m_tracking) return;

        if (m_group_dir == PHASE_UP_TREND) {
            SwingPoint lh = swing.GetLatestHigh();
            if (!lh.is_valid) return;
            if (phase.HasHigherLowReady() && phase.HasHigherHighReady()
                && bar_body_high > lh.price) {
                AddContinuationWaves(snap_lh, snap_ll, snap_ph, snap_pl,
                                     PHASE_UP_TREND, bar_time, bar_high, bar_low);
            }
        } else if (m_group_dir == PHASE_DOWN_TREND) {
            SwingPoint ll = swing.GetLatestLow();
            if (!ll.is_valid) return;
            if (phase.HasLowerHighReady() && phase.HasLowerLowReady()
                && bar_body_low < ll.price) {
                AddContinuationWaves(snap_lh, snap_ll, snap_ph, snap_pl,
                                     PHASE_DOWN_TREND, bar_time, bar_high, bar_low);
            }
        }
    }

    int  GetWaveCount() { return m_wave_count; }

    bool GetWave(const int idx, Wave &out) {
        if (idx < 0 || idx >= m_wave_count) return false;
        out = m_waves[idx];
        return true;
    }

    bool IsTracking()        { return m_tracking; }
    bool IsGroupActive()     { return m_group_active; }
    int  GetLastWaveNo()     { return m_last_wave_no; }
};

#endif
