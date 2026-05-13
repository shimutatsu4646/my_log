#ifndef SABAI_SYSTEM_DRAWING_WAVE_RENDERER_MQH
#define SABAI_SYSTEM_DRAWING_WAVE_RENDERER_MQH

#include "../Types.mqh"
#include "../WaveDetector.mqh"
#include "ObjectHelper.mqh"

#define SABAI_WAVE_PREFIX SABAI_OBJ_PREFIX "WV_"

// system_doc.md L87-141 で定義される第1〜N波を描画する。
// - 線種は全波で STYLE_SOLID, 太さ 2。
// - 色は上昇トレンド=緑 / 下降トレンド=赤。推進波・調整波で区別しない。
// - 波番号ラベル ("1" / "2" / "3" / "4" / "5" / ...) を起点に貼る。
//   推進波(奇数)の起点は反対 extremum (UP=安値, DOWN=高値) → 価格に重ならない側へ
//   調整波(偶数)の起点は extremum 側  (UP=高値, DOWN=安値) → 価格に重ならない側へ
class CWaveRenderer {
public:
    void Init() {}

    void Clear() {
        CObjectHelper::DeleteByPrefix(SABAI_WAVE_PREFIX);
    }

    void UpsertWave(const Wave &w) {
        if (!w.segment.is_valid
            || !w.segment.start.is_valid
            || !w.segment.end.is_valid) return;

        color clr;
        if (w.group_dir == PHASE_UP_TREND)        clr = clrGreen;
        else if (w.group_dir == PHASE_DOWN_TREND) clr = clrRed;
        else                                      clr = clrGray;

        string suffix = IntegerToString((long)w.group_id) + "_" + IntegerToString(w.wave_no);
        string line_name = SABAI_WAVE_PREFIX + "L_" + suffix;
        CObjectHelper::UpsertTrendLine(line_name,
                                       w.segment.start.time, w.segment.start.price,
                                       w.segment.end.time,   w.segment.end.price,
                                       clr, STYLE_SOLID, 2, false);

        string label_name = SABAI_WAVE_PREFIX + "T_" + suffix;
        ENUM_ANCHOR_POINT anchor = GetLabelAnchor(w.wave_no, w.group_dir);
        CObjectHelper::UpsertTextLabel(label_name,
                                       w.segment.start.time, w.segment.start.price,
                                       IntegerToString(w.wave_no),
                                       clr, 10, "Arial", anchor);
    }

private:
    // 奇数=推進、偶数=調整 でアンカーを決定（起点に貼る前提）。
    // 上昇: 奇数 start=安値 → ラベル下 (ANCHOR_UPPER)、偶数 start=高値 → ラベル上 (ANCHOR_LOWER)
    // 下降: 奇数 start=高値 → ラベル上 (ANCHOR_LOWER)、偶数 start=安値 → ラベル下 (ANCHOR_UPPER)
    ENUM_ANCHOR_POINT GetLabelAnchor(const int wave_no, const MarketPhase dir) {
        bool is_odd = ((wave_no % 2) == 1);
        bool above;
        if (dir == PHASE_UP_TREND) above = !is_odd;
        else                       above = is_odd;
        return above ? ANCHOR_LOWER : ANCHOR_UPPER;
    }
};

#endif
