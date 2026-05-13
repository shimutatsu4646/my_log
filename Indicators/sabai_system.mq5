#property copyright "SabaiSystem"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <MyCode/SabaiSystem/Types.mqh>
#include <MyCode/SabaiSystem/SwingDetector.mqh>
#include <MyCode/SabaiSystem/MarketPhaseDetector.mqh>
#include <MyCode/SabaiSystem/QuickBiasDetector.mqh>
#include <MyCode/SabaiSystem/SlowBiasDetector.mqh>
#include <MyCode/SabaiSystem/TimeframeAnalyzer.mqh>
#include <MyCode/SabaiSystem/MTFAnalyzer.mqh>
#include <MyCode/SabaiSystem/Drawing/ObjectHelper.mqh>
#include <MyCode/SabaiSystem/Drawing/SwingRenderer.mqh>
#include <MyCode/SabaiSystem/Drawing/PhaseRenderer.mqh>
#include <MyCode/SabaiSystem/Drawing/BiasRenderer.mqh>
#include <MyCode/SabaiSystem/Drawing/WaveRenderer.mqh>
#include <MyCode/SabaiSystem/QuickBiasGaze.mqh>
#include <MyCode/SabaiSystem/Drawing/InfoPanel.mqh>

input int  InputBarsToLookBack = 2000;
input int  InputSwingSpan      = 6;
input bool InputQuickBiasBgFlag = false;

CMTFAnalyzer   g_mtf;
CSwingRenderer g_swing_renderer;
CPhaseRenderer g_phase_renderer;
CBiasRenderer  g_bias_renderer;
CWaveRenderer  g_wave_renderer;
CInfoPanel     g_info_panel;

int OnInit() {
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    ChartSetInteger(0, CHART_FOREGROUND, true);

    ENUM_TIMEFRAMES chart_tf = (ENUM_TIMEFRAMES)_Period;
    g_mtf.Init(InputSwingSpan, InputBarsToLookBack, chart_tf);

    g_swing_renderer.Init();
    g_phase_renderer.Init();
    g_bias_renderer.Init();
    g_wave_renderer.Init();
    g_info_panel.Init();

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    CObjectHelper::DeleteAll();
}

void DrawUpperTFSwings(const int tf_slot,
                       const ENUM_TIMEFRAMES upper_tf,
                       const datetime &chart_time[],
                       const double &chart_high[],
                       const double &chart_low[],
                       const int chart_total,
                       const int chart_start) {
    CTimeframeAnalyzer *analyzer = g_mtf.GetAnalyzer(tf_slot);
    CSwingDetector *swing = analyzer.GetSwing();
    int hist_count = swing.GetHistoryCount();

    ENUM_TIMEFRAMES tf = upper_tf;
    int tf_seconds = PeriodSeconds(tf);
    if (tf_seconds <= 0) tf_seconds = 86400;

    int chart_seconds = PeriodSeconds(_Period);
    if (chart_seconds <= 0) chart_seconds = 14400;
    int bars_needed = (int)MathCeil((double)g_mtf.GetBarsToLookback() *
                                    (double)chart_seconds / (double)tf_seconds)
                      + g_mtf.GetSwingSpan() * 4;
    bars_needed = MathMax(bars_needed, hist_count + 50);

    datetime upper_time[];
    ArraySetAsSeries(upper_time, false);
    int copied = CopyTime(_Symbol, tf, 0, bars_needed, upper_time);
    if (copied <= 0) return;

    for (int h = 0; h < hist_count; h++) {
        SwingPoint pt = swing.GetHistoryAt(h);
        if (!pt.is_valid) continue;

        int bar_idx_in_upper = -1;
        for (int u = 0; u < copied; u++) {
            if (upper_time[u] == pt.time) {
                bar_idx_in_upper = u;
                break;
            }
        }
        if (bar_idx_in_upper < 0) continue;

        datetime bar_open_time = upper_time[bar_idx_in_upper];
        datetime bar_next_time = (bar_idx_in_upper + 1 < copied)
            ? upper_time[bar_idx_in_upper + 1]
            : (bar_open_time + tf_seconds);

        bool is_high = (pt.price > pt.body_price);

        if (is_high) {
            int best_idx = -1;
            double max_h = -DBL_MAX;
            for (int d = chart_start; d < chart_total; d++) {
                if (chart_time[d] < bar_open_time || chart_time[d] >= bar_next_time)
                    continue;
                if (chart_high[d] > max_h) {
                    max_h = chart_high[d];
                    best_idx = d;
                }
            }
            if (best_idx >= 0) {
                g_swing_renderer.DrawUpperTFSwingHigh(tf, chart_time[best_idx], max_h);
            }
        } else {
            int best_idx = -1;
            double min_l = DBL_MAX;
            for (int d = chart_start; d < chart_total; d++) {
                if (chart_time[d] < bar_open_time || chart_time[d] >= bar_next_time)
                    continue;
                if (chart_low[d] < min_l) {
                    min_l = chart_low[d];
                    best_idx = d;
                }
            }
            if (best_idx >= 0) {
                g_swing_renderer.DrawUpperTFSwingLow(tf, chart_time[best_idx], min_l);
            }
        }
    }
}

void DrawUpperTFSlowBiasLines(const int tf_slot, const ENUM_TIMEFRAMES tf) {
    CTimeframeAnalyzer *analyzer = g_mtf.GetAnalyzer(tf_slot);
    if (analyzer == NULL) return;
    CSlowBiasDetector *sb = analyzer.GetSlowBias();
    if (sb == NULL) return;

    datetime now = TimeCurrent();

    int n_pb = sb.GetPullbackLineSegmentCount();
    for (int i = 0; i < n_pb; i++) {
        SlowBiasLineSegment seg;
        if (!sb.GetPullbackLineSegment(i, seg)) continue;
        datetime end_t = (seg.end_time > 0) ? seg.end_time : now;
        g_bias_renderer.DrawUpperTFPullbackSegment(tf_slot, tf, i,
                                                    seg.start_time, end_t,
                                                    seg.price);
    }

    int n_rb = sb.GetReboundLineSegmentCount();
    for (int i = 0; i < n_rb; i++) {
        SlowBiasLineSegment seg;
        if (!sb.GetReboundLineSegment(i, seg)) continue;
        datetime end_t = (seg.end_time > 0) ? seg.end_time : now;
        g_bias_renderer.DrawUpperTFReboundSegment(tf_slot, tf, i,
                                                   seg.start_time, end_t,
                                                   seg.price);
    }
}

void DrawUpperTFRangeLines(const int tf_slot, const ENUM_TIMEFRAMES tf) {
    TimeframeState state = g_mtf.GetState(tf_slot);
    int range_count = ArraySize(state.active_ranges);

    // 共有サフィックスを事前構築する。
    // active_ranges は r_idx (= MarketPhaseDetector の m_all_ranges index) 順に格納されているので、
    // 子レンジが親側に shared_*_with_parent で参照されるたびに親の suffix に "_<child+1>" を積み増す。
    string upper_suffix[];
    string lower_suffix[];
    ArrayResize(upper_suffix, range_count);
    ArrayResize(lower_suffix, range_count);
    for (int i = 0; i < range_count; i++) {
        upper_suffix[i] = "";
        lower_suffix[i] = "";
    }
    for (int r = 0; r < range_count; r++) {
        if (state.active_ranges[r].confirmed_time == 0) continue;
        int parent = state.active_ranges[r].parent_range_idx;
        if (parent < 0 || parent >= range_count) continue;
        if (state.active_ranges[r].shares_upper_with_parent) {
            upper_suffix[parent] += "_" + IntegerToString(r + 1);
        }
        if (state.active_ranges[r].shares_lower_with_parent) {
            lower_suffix[parent] += "_" + IntegerToString(r + 1);
        }
    }

    for (int r = 0; r < range_count; r++) {
        if (state.active_ranges[r].confirmed_time == 0) continue;
        // is_active=true なら TimeCurrent() まで、ended_time があればそこまで描画
        datetime end_time = (state.active_ranges[r].ended_time > 0)
            ? state.active_ranges[r].ended_time : TimeCurrent();
        // shared 側は親レンジ側のラインを流用するため、子側では描画しない。
        if (!state.active_ranges[r].shares_upper_with_parent) {
            g_phase_renderer.DrawUpperTFRangeLine(tf, state.active_ranges[r].upper_bound,
                                                  state.active_ranges[r].upper_start_time,
                                                  end_time, true,
                                                  r + 1, upper_suffix[r]);
        }
        if (!state.active_ranges[r].shares_lower_with_parent) {
            g_phase_renderer.DrawUpperTFRangeLine(tf, state.active_ranges[r].lower_bound,
                                                  state.active_ranges[r].lower_start_time,
                                                  end_time, false,
                                                  r + 1, lower_suffix[r]);
        }
    }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    int swing_span = MathMax(1, InputSwingSpan);
    int bars_to_lookback = MathMax(1, InputBarsToLookBack);

    if (rates_total < swing_span * 2 + 1)
        return 0;

    if (prev_calculated == rates_total)
        return rates_total;

    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);

    int chart_period_seconds = PeriodSeconds(_Period);
    if (chart_period_seconds <= 0) chart_period_seconds = 14400;

    g_swing_renderer.Clear();
    g_phase_renderer.Clear();
    g_bias_renderer.Clear();
    g_wave_renderer.Clear();
    g_info_panel.Clear();

    // 1) 上位足を先に全 bar 解析する（上位足 TF の描画・InfoPanel 用の状態を揃える）。
    g_mtf.AnalyzeUpperTFsOnly();

    // 2) chart TF を bar ごとに処理＆描画する。chart TF 用アナライザは g_mtf 内インスタンスを使用。
    int chart_slot = g_mtf.GetChartSlot();
    CTimeframeAnalyzer *chart_analyzer = g_mtf.GetAnalyzer(chart_slot);
    chart_analyzer.Reset();
    chart_analyzer.Init((ENUM_TIMEFRAMES)_Period, swing_span);

    int base_limit = MathMax(swing_span, rates_total - bars_to_lookback);
    // 末尾 swing_span 本もレンジブレイク等の判定対象に含めるため rates_total まで回す。
    // スイング確定は DetectSwingHigh/Low 内のガードで右側 swing_span 本未満なら成立しない。
    int end_index  = rates_total;

    for (int i = base_limit; i < end_index; i++) {
        chart_analyzer.ProcessBar(i, time, open, high, low, close, rates_total);

        CSwingDetector       *swing = chart_analyzer.GetSwing();
        CMarketPhaseDetector *phase = chart_analyzer.GetPhase();
        CSlowBiasDetector    *sb    = chart_analyzer.GetSlowBias();
        CQuickBiasGaze       *gaze  = chart_analyzer.GetGaze();

        if (swing.IsCurrentSwingHigh()) {
            g_swing_renderer.DrawChartSwingHigh(time[i], high[i]);
        }
        if (swing.IsCurrentSwingLow()) {
            g_swing_renderer.DrawChartSwingLow(time[i], low[i]);
        }

        MarketPhase current_phase = phase.GetCurrentPhase();
        color chart_color = GetTimeframeColor((ENUM_TIMEFRAMES)_Period);

        if (phase.HasPhaseChanged()) {
            MarketPhase old_phase = phase.GetPreviousPhase();

            if (old_phase == PHASE_UP_TREND)
                g_phase_renderer.DrawUpTrendEnded(time[i]);
            else if (old_phase == PHASE_DOWN_TREND)
                g_phase_renderer.DrawDownTrendEnded(time[i]);
            else if (old_phase == PHASE_RANGE) {
                g_phase_renderer.DrawRangeEnded(time[i]);
                g_phase_renderer.CloseAllChartRangeLines(time[i]);
            }

            if (current_phase == PHASE_UP_TREND) {
                g_phase_renderer.DrawUpTrendConfirmed(time[i]);
            }
            else if (current_phase == PHASE_DOWN_TREND) {
                g_phase_renderer.DrawDownTrendConfirmed(time[i]);
            }
            else if (current_phase == PHASE_RANGE) {
                g_phase_renderer.DrawRangeConfirmed(time[i]);
            }
        }

        // レンジ確定イベント: 個別の range_idx を指定して線を引く
        if (phase.HasRangeConfirmedEvent()) {
            int r_idx = phase.GetLastRangeConfirmedIdx();
            RangeZone rz;
            if (r_idx >= 0 && phase.GetRange(r_idx, rz)) {
                // shared 側は親のラインを流用するため、子側では描画せず、親ラベルに子の通番を追加する。
                if (!rz.shares_upper_with_parent) {
                    g_phase_renderer.StartChartRangeLineUpper(
                        r_idx, rz.upper_bound, rz.upper_start_time, chart_color);
                } else if (rz.parent_range_idx >= 0) {
                    g_phase_renderer.AppendSharedChildToChartRangeUpper(
                        rz.parent_range_idx, r_idx + 1);
                }
                if (!rz.shares_lower_with_parent) {
                    g_phase_renderer.StartChartRangeLineLower(
                        r_idx, rz.lower_bound, rz.lower_start_time, chart_color);
                } else if (rz.parent_range_idx >= 0) {
                    g_phase_renderer.AppendSharedChildToChartRangeLower(
                        rz.parent_range_idx, r_idx + 1);
                }
            }
        }

        // レンジ終了（ブレイク）イベント: この bar で ended_time が一致する全レンジを close（ネスト対応・複数同時ブレイク対応）
        if (phase.HasRangeEndedEvent()) {
            int all_rc = phase.GetAllRangeCount();
            for (int rr = 0; rr < all_rc; rr++) {
                RangeZone rz_end;
                if (phase.GetRange(rr, rz_end)) {
                    if (!rz_end.is_active && rz_end.ended_time == time[i]) {
                        // shared 側は子側で描画していないので閉じる必要なし。親側で閉じられる。
                        if (!rz_end.shares_upper_with_parent) {
                            g_phase_renderer.CloseChartRangeLineUpper(rr, time[i]);
                        }
                        if (!rz_end.shares_lower_with_parent) {
                            g_phase_renderer.CloseChartRangeLineLower(rr, time[i]);
                        }
                    }
                }
            }
        }

        BiasDirection slow_dir = sb.GetDirection();
        if (sb.HasBiasChanged()) {
            BiasDirection old_dir = sb.GetPrevDirection();
            if (old_dir == BIAS_BULLISH) {
                g_bias_renderer.CloseChartPullbackLine(time[i]);
            } else if (old_dir == BIAS_BEARISH) {
                g_bias_renderer.CloseChartReboundLine(time[i]);
            }

            if (slow_dir == BIAS_BULLISH && sb.IsPullbackLineActive()) {
                g_bias_renderer.StartChartPullbackLine(
                    sb.GetPullbackLineStartTime(), sb.GetPullbackLinePrice());
            } else if (slow_dir == BIAS_BEARISH && sb.IsReboundLineActive()) {
                g_bias_renderer.StartChartReboundLine(
                    sb.GetReboundLineStartTime(), sb.GetReboundLinePrice());
            }
        } else {
            if (sb.HasPullbackLineChanged()) {
                g_bias_renderer.CloseChartPullbackLine(time[i]);
                g_bias_renderer.StartChartPullbackLine(
                    sb.GetPullbackLineStartTime(), sb.GetPullbackLinePrice());
            }
            if (sb.HasReboundLineChanged()) {
                g_bias_renderer.CloseChartReboundLine(time[i]);
                g_bias_renderer.StartChartReboundLine(
                    sb.GetReboundLineStartTime(), sb.GetReboundLinePrice());
            }
        }

        // 背景色: chart TF アナライザ内部の gaze 状態を参照
        if (InputQuickBiasBgFlag) {
            BiasDirection bg_dir = gaze.GetDirection();
            if (gaze.HasValidBounds()) {
                g_bias_renderer.RecordBgSegment(bg_dir, time[i],
                                                gaze.GetUpper(),
                                                gaze.GetLower());
            } else {
                g_bias_renderer.RecordBgSegment(BIAS_UNKNOWN, time[i], 0.0, 0.0);
            }
        }

        g_phase_renderer.ExtendActiveLines(time[i]);
        g_bias_renderer.ExtendActiveLines(time[i]);

        // 波: 検出済み Wave 全部を upsert する。
        // - 過去 wave は frozen で内容が変わらないが、Clear() で全消去しているので
        //   再描画のため毎バー upsert する（オブジェクト名は group_id+wave_no 一意なので idempotent）。
        // - 最新 tracking 波は end が逐次更新されるためどのみち毎バー upsert が必要。
        CWaveDetector *waves = chart_analyzer.GetWaves();
        int wave_count = waves.GetWaveCount();
        for (int w = 0; w < wave_count; w++) {
            Wave wv;
            if (waves.GetWave(w, wv)) {
                g_wave_renderer.UpsertWave(wv);
            }
        }
    }

    if (InputQuickBiasBgFlag) {
        g_bias_renderer.FlushBgSegments(chart_period_seconds, time, rates_total);
    }

    int upper_count = g_mtf.GetUpperTFCount();
    int total_count = g_mtf.GetTotalTFCount();

    ENUM_TIMEFRAMES chart_tf = (ENUM_TIMEFRAMES)_Period;
    int swing_tf_slot = upper_count - 1;
    ENUM_TIMEFRAMES swing_tf = GetUpperSwingTF(chart_tf);

    if (swing_tf_slot >= 0 && swing_tf != PERIOD_CURRENT) {
        DrawUpperTFSwings(swing_tf_slot, swing_tf, time, high, low, rates_total, base_limit);
    }

    for (int slot = 0; slot < upper_count; slot++) {
        ENUM_TIMEFRAMES tf = GetTimeframeByIndex(slot);
        DrawUpperTFSlowBiasLines(slot, tf);
        DrawUpperTFRangeLines(slot, tf);
    }

    TimeframeState panel_states[];
    ArrayResize(panel_states, total_count);
    for (int i = 0; i < upper_count; i++) {
        panel_states[i] = g_mtf.GetState(i);
    }
    panel_states[total_count - 1] = chart_analyzer.GetState();
    g_info_panel.Update(panel_states, total_count);

    return rates_total;
}
