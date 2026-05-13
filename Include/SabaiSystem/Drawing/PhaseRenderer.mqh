#ifndef SABAI_SYSTEM_DRAWING_PHASE_RENDERER_MQH
#define SABAI_SYSTEM_DRAWING_PHASE_RENDERER_MQH

#include "../Types.mqh"
#include "../MarketPhaseDetector.mqh"
#include "ObjectHelper.mqh"

#define SABAI_PHASE_PREFIX     SABAI_OBJ_PREFIX "PH_"
#define SABAI_PHASE_HL_PREFIX  SABAI_PHASE_PREFIX "HL_"
// レンジラインの末端ラベルのフォントサイズ。(9にするとInfoPanelの文字サイズと同じになる)
#define SABAI_RANGE_LABEL_FONT_SIZE 5

class CPhaseRenderer {
private:
    int m_line_shift_multiplier;

    struct ActiveHLine {
        string   name;
        string   label_name;
        bool     is_upper;
        datetime start_time;
        double   price;
        color    clr;
        int      style;
        int      width;
        bool     active;
        int      range_number;
        string   shared_suffix;
    };

    ActiveHLine m_chart_range_lines[];
    int         m_chart_range_line_count;

    ActiveHLine m_upper_tf_lines[];
    int         m_upper_tf_line_count;

    void InitActiveLine(ActiveHLine &line) {
        line.name          = "";
        line.label_name    = "";
        line.is_upper      = false;
        line.start_time    = 0;
        line.price         = 0.0;
        line.clr           = clrNONE;
        line.style         = STYLE_SOLID;
        line.width         = SABAI_STRUCTURE_LANDSCAPE_LINE_WIDTH;
        line.active        = false;
        line.range_number  = 0;
        line.shared_suffix = "";
    }

    // 指定 (time, price) から pixel_offset だけ右に移動したときの時刻を返す。
    // チャートの現在スケールを用いて変換する。変換失敗時は base_time をそのまま返す。
    datetime ShiftTimeByPixels(const datetime base_time,
                               const double price,
                               const int pixel_offset) {
        int x = 0, y = 0;
        if (!ChartTimePriceToXY(0, 0, base_time, price, x, y))
            return base_time;
        int sub = 0;
        datetime new_time = base_time;
        double   new_price = price;
        if (!ChartXYToTimePrice(0, x + pixel_offset, y, sub, new_time, new_price))
            return base_time;
        if (new_time <= 0) return base_time;
        return new_time;
    }

    // チャート足ラベルは始点（start_time）にそのまま描画する。水平オフセットはかけない。
    void UpsertRangeLineLabel(const ActiveHLine &line) {
        if (line.label_name == "") return;
        string prefix = GetTimeframePrefix((ENUM_TIMEFRAMES)_Period);
        string base = line.is_upper ? "Upper" : "Lower";
        string text = prefix + base + "_" + IntegerToString(line.range_number) + line.shared_suffix;
        ENUM_ANCHOR_POINT anchor = line.is_upper ? ANCHOR_LOWER : ANCHOR_UPPER;
        CObjectHelper::UpsertTextLabel(line.label_name, line.start_time, line.price,
                                       text, clrDarkOrange,
                                       SABAI_RANGE_LABEL_FONT_SIZE,
                                       "Arial", anchor);
    }

    void GrowUpperTFLines() {
        int new_count = m_upper_tf_line_count + 2;
        ArrayResize(m_upper_tf_lines, new_count + 10);
    }

    // 縦方向のオフセットを「チャート足から何段上か」で決める。
    // ラベルの x オフセット (GetUpperTFLabelPixelOffset) と同じ段数ルールに揃えることで、
    // 上位足が近いほど縦横ともにオフセットが小さくなるようにする。
    double GetShiftedPrice(const double base_price,
                           const ENUM_TIMEFRAMES tf,
                           const bool shift_up) {
        int chart_idx = GetTimeframeIndex((ENUM_TIMEFRAMES)_Period);
        int step = chart_idx - GetTimeframeIndex(tf);
        if (step < 0) step = 0;
        double shift = (double)(m_line_shift_multiplier * step) * _Point;
        return shift_up ? (base_price + shift) : (base_price - shift);
    }

    // 上位足ラベルの x オフセットを「該当上位足がチャート足から何段上か」で決める。
    // チャート足=0px、1段上=130px、2段上=260pxの水平方向オフセットを適用（ラベルの重なり回避用）。絶対的なTF順序には依存しない。
    int GetUpperTFLabelPixelOffset(const ENUM_TIMEFRAMES tf, const bool is_upper) {
        int chart_idx = GetTimeframeIndex((ENUM_TIMEFRAMES)_Period);
        int step = chart_idx - GetTimeframeIndex(tf);
        if (step < 0) step = 0;
        // 130(pixel)の理由：最大縮小の1つ手前のズームアウトの状態で、レンジラベルが重複しない間隔。ズームしても離れすぎていない。
        return 130 * step;
    }

public:
    void Init(const int line_shift_multiplier = 100) { // 上位足のレンジラインのyオフセット
        m_line_shift_multiplier = line_shift_multiplier;
        m_chart_range_line_count = 0;
        ArrayFree(m_chart_range_lines);
        m_upper_tf_line_count = 0;
        ArrayFree(m_upper_tf_lines);
    }

    void Clear() {
        CObjectHelper::DeleteByPrefix(SABAI_PHASE_PREFIX);
        m_chart_range_line_count = 0;
        ArrayFree(m_chart_range_lines);
        m_upper_tf_line_count = 0;
        ArrayFree(m_upper_tf_lines);
    }

    // レンジペアを range_idx（MarketPhaseDetector の全レンジ index）で管理する。
    // 個別ペアを任意のタイミングで close できるようにする。
    int EnsureRangeCapacity(const int range_idx) {
        int needed = (range_idx + 1) * 2;
        if (ArraySize(m_chart_range_lines) < needed) {
            int old_size = ArraySize(m_chart_range_lines);
            ArrayResize(m_chart_range_lines, needed + 10);
            for (int i = old_size; i < ArraySize(m_chart_range_lines); i++) {
                InitActiveLine(m_chart_range_lines[i]);
            }
        }
        if (m_chart_range_line_count < needed) m_chart_range_line_count = needed;
        return range_idx * 2;
    }

    void StartChartRangeLineUpper(const int range_idx,
                                  const double upper,
                                  const datetime upper_start,
                                  const color clr) {
        int base = EnsureRangeCapacity(range_idx);
        ActiveHLine upper_line;
        InitActiveLine(upper_line);
        string suffix = IntegerToString(range_idx + 1) + "_" + IntegerToString((long)upper_start);
        upper_line.name          = SABAI_PHASE_HL_PREFIX "CRU_" + suffix;
        upper_line.label_name    = SABAI_PHASE_HL_PREFIX "CRU_LBL_" + suffix;
        upper_line.is_upper      = true;
        upper_line.start_time    = upper_start;
        upper_line.price         = upper;
        upper_line.clr           = clr;
        upper_line.style         = STYLE_DASHDOTDOT;
        upper_line.width         = SABAI_STRUCTURE_LANDSCAPE_LINE_WIDTH;
        upper_line.active        = true;
        upper_line.range_number  = range_idx + 1;
        upper_line.shared_suffix = "";
        m_chart_range_lines[base] = upper_line;
        UpsertRangeLineLabel(m_chart_range_lines[base]);
    }

    void StartChartRangeLineLower(const int range_idx,
                                  const double lower,
                                  const datetime lower_start,
                                  const color clr) {
        int base = EnsureRangeCapacity(range_idx);
        ActiveHLine lower_line;
        InitActiveLine(lower_line);
        string suffix = IntegerToString(range_idx + 1) + "_" + IntegerToString((long)lower_start);
        lower_line.name          = SABAI_PHASE_HL_PREFIX "CRL_" + suffix;
        lower_line.label_name    = SABAI_PHASE_HL_PREFIX "CRL_LBL_" + suffix;
        lower_line.is_upper      = false;
        lower_line.start_time    = lower_start;
        lower_line.price         = lower;
        lower_line.clr           = clr;
        lower_line.style         = STYLE_DASHDOTDOT;
        lower_line.width         = SABAI_STRUCTURE_LANDSCAPE_LINE_WIDTH;
        lower_line.active        = true;
        lower_line.range_number  = range_idx + 1;
        lower_line.shared_suffix = "";
        m_chart_range_lines[base + 1] = lower_line;
        UpsertRangeLineLabel(m_chart_range_lines[base + 1]);
    }

    // 親レンジの上限ラインに子レンジの通番を追加する。
    // 子レンジが親と上限を共有して新規確定したときに呼ばれ、ラベル末尾に "_<child_seq_no>" を積み増す。
    void AppendSharedChildToChartRangeUpper(const int parent_idx, const int child_seq_no) {
        int base = parent_idx * 2;
        if (base < 0 || base >= ArraySize(m_chart_range_lines)) return;
        if (m_chart_range_lines[base].label_name == "") return;
        m_chart_range_lines[base].shared_suffix += "_" + IntegerToString(child_seq_no);
        UpsertRangeLineLabel(m_chart_range_lines[base]);
    }

    void AppendSharedChildToChartRangeLower(const int parent_idx, const int child_seq_no) {
        int base = parent_idx * 2;
        if (base < 0 || base + 1 >= ArraySize(m_chart_range_lines)) return;
        if (m_chart_range_lines[base + 1].label_name == "") return;
        m_chart_range_lines[base + 1].shared_suffix += "_" + IntegerToString(child_seq_no);
        UpsertRangeLineLabel(m_chart_range_lines[base + 1]);
    }

    void StartChartRangeLinePair(const int range_idx,
                                 const double upper, const double lower,
                                 const datetime upper_start, const datetime lower_start,
                                 const color clr) {
        StartChartRangeLineUpper(range_idx, upper, upper_start, clr);
        StartChartRangeLineLower(range_idx, lower, lower_start, clr);
    }

    void CloseChartRangeLineUpper(const int range_idx, const datetime end_time) {
        int base = range_idx * 2;
        if (base < 0 || base >= ArraySize(m_chart_range_lines)) return;
        if (!m_chart_range_lines[base].active) return;
        CObjectHelper::UpsertHLine(m_chart_range_lines[base].name,
                                   m_chart_range_lines[base].start_time,
                                   end_time,
                                   m_chart_range_lines[base].price,
                                   m_chart_range_lines[base].clr,
                                   m_chart_range_lines[base].style,
                                   m_chart_range_lines[base].width);
        m_chart_range_lines[base].active = false;
    }

    void CloseChartRangeLineLower(const int range_idx, const datetime end_time) {
        int base = range_idx * 2;
        if (base < 0 || base + 1 >= ArraySize(m_chart_range_lines)) return;
        if (!m_chart_range_lines[base + 1].active) return;
        CObjectHelper::UpsertHLine(m_chart_range_lines[base + 1].name,
                                   m_chart_range_lines[base + 1].start_time,
                                   end_time,
                                   m_chart_range_lines[base + 1].price,
                                   m_chart_range_lines[base + 1].clr,
                                   m_chart_range_lines[base + 1].style,
                                   m_chart_range_lines[base + 1].width);
        m_chart_range_lines[base + 1].active = false;
    }

    void CloseChartRangeLinePair(const int range_idx, const datetime end_time) {
        CloseChartRangeLineUpper(range_idx, end_time);
        CloseChartRangeLineLower(range_idx, end_time);
    }

    void CloseAllChartRangeLines(const datetime end_time) {
        for (int i = 0; i < m_chart_range_line_count; i++) {
            if (m_chart_range_lines[i].active) {
                CObjectHelper::UpsertHLine(m_chart_range_lines[i].name,
                                           m_chart_range_lines[i].start_time,
                                           end_time,
                                           m_chart_range_lines[i].price,
                                           m_chart_range_lines[i].clr,
                                           m_chart_range_lines[i].style,
                                           m_chart_range_lines[i].width);
                m_chart_range_lines[i].active = false;
            }
        }
    }

    void DrawUpperTFRangeLine(const ENUM_TIMEFRAMES tf,
                              const double price,
                              const datetime start_time,
                              const datetime end_time,
                              const bool is_upper_bound,
                              const int range_number,
                              const string shared_suffix) {
        color clr = GetTimeframeColor(tf);
        string tag = is_upper_bound ? "URU" : "URL";
        string suffix = GetTimeframePrefix(tf) +
                        IntegerToString(range_number) + "_" +
                        IntegerToString((long)start_time);
        string name       = SABAI_PHASE_HL_PREFIX + tag + "_" + suffix;
        string label_name = SABAI_PHASE_HL_PREFIX + tag + "_LBL_" + suffix;
        double shifted = GetShiftedPrice(price, tf, is_upper_bound);
        CObjectHelper::UpsertHLine(name, start_time, end_time, shifted,
                                   clr, STYLE_DASHDOTDOT, SABAI_STRUCTURE_LANDSCAPE_LINE_WIDTH);
        string prefix = GetTimeframePrefix(tf);
        string base_text = is_upper_bound ? "Upper" : "Lower";
        string text = prefix + base_text + "_" + IntegerToString(range_number) + shared_suffix;
        ENUM_ANCHOR_POINT anchor = is_upper_bound ? ANCHOR_LOWER : ANCHOR_UPPER;
        int pixel_offset = GetUpperTFLabelPixelOffset(tf, is_upper_bound);
        datetime label_time = ShiftTimeByPixels(start_time, shifted, pixel_offset);
        CObjectHelper::UpsertTextLabel(label_name, label_time, shifted, text, clrDarkOrange,
                                       SABAI_RANGE_LABEL_FONT_SIZE, "Arial", anchor);
    }

    void ExtendActiveLines(const datetime current_time) {
        for (int i = 0; i < m_chart_range_line_count; i++) {
            if (m_chart_range_lines[i].active) {
                CObjectHelper::UpsertHLine(m_chart_range_lines[i].name,
                                           m_chart_range_lines[i].start_time,
                                           current_time,
                                           m_chart_range_lines[i].price,
                                           m_chart_range_lines[i].clr,
                                           m_chart_range_lines[i].style,
                                           m_chart_range_lines[i].width);
            }
        }
    }
};

#endif
