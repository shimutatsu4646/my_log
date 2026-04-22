#ifndef SABAI_SYSTEM_DRAWING_SWING_RENDERER_MQH
#define SABAI_SYSTEM_DRAWING_SWING_RENDERER_MQH

#include "../Types.mqh"
#include "../SwingDetector.mqh"
#include "ObjectHelper.mqh"

#define SABAI_SWING_PREFIX        SABAI_OBJ_PREFIX "SW_"
#define SABAI_SWING_CHART_PREFIX  SABAI_SWING_PREFIX "C_"
#define SABAI_SWING_UPPER_PREFIX  SABAI_SWING_PREFIX "U_"

class CSwingRenderer {
private:
    int    m_chart_label_offset_pts;
    int    m_upper_label_offset_pts;
    int    m_font_size;
    color  m_chart_high_color;
    color  m_chart_low_color;
    color  m_upper_high_color;
    color  m_upper_low_color;

    void UpsertSwingMarker(const string name,
                           const color box_color,
                           const datetime marker_time,
                           const double anchor_price,
                           const ENUM_ANCHOR_POINT anchor) {
        int obj_index = ObjectFind(0, name);
        if (obj_index < 0) {
            if (!ObjectCreate(0, name, OBJ_TEXT, 0, marker_time, anchor_price))
                return;
        } else {
            int obj_type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
            if (obj_type != OBJ_TEXT) {
                ObjectDelete(0, name);
                if (!ObjectCreate(0, name, OBJ_TEXT, 0, marker_time, anchor_price))
                    return;
            } else {
                ObjectMove(0, name, 0, marker_time, anchor_price);
            }
        }

        ObjectSetString(0, name, OBJPROP_TEXT, ShortToString(0x25A0));
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_font_size);
        // High 側は ANCHOR_LOWER（ボックス下端）、Low 側は ANCHOR_UPPER（ボックス上端）を
        // アンカーにすることで、フォントのグリフ中心ズレによる上ヒゲ被りを防ぐ。
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
        ObjectSetInteger(0, name, OBJPROP_COLOR, box_color);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }

public:
    void Init(const int chart_offset_pts = 100,
              const int upper_offset_pts = 220,
              const int font_size = 7,
              const color high_color = clrAqua,
              const color low_color = clrPink,
              const color upper_high_color = clrBlue,
              const color upper_low_color = clrRed) {
        m_chart_label_offset_pts = chart_offset_pts;
        m_upper_label_offset_pts = upper_offset_pts;
        m_font_size        = font_size;
        m_chart_high_color = high_color;
        m_chart_low_color  = low_color;
        m_upper_high_color = upper_high_color;
        m_upper_low_color  = upper_low_color;
    }

    void Clear() {
        CObjectHelper::DeleteByPrefix(SABAI_SWING_PREFIX);
    }

    void DrawChartSwingHigh(const datetime time, const double high_price) {
        string name = SABAI_SWING_CHART_PREFIX "H_" + IntegerToString((long)time);
        double anchor = high_price + (double)m_chart_label_offset_pts * _Point;
        UpsertSwingMarker(name, m_chart_high_color, time, anchor, ANCHOR_LOWER);
    }

    void DrawChartSwingLow(const datetime time, const double low_price) {
        string name = SABAI_SWING_CHART_PREFIX "L_" + IntegerToString((long)time);
        double anchor = low_price - (double)m_chart_label_offset_pts * _Point;
        UpsertSwingMarker(name, m_chart_low_color, time, anchor, ANCHOR_UPPER);
    }

    void DrawUpperTFSwingHigh(const ENUM_TIMEFRAMES tf,
                              const datetime chart_bar_time,
                              const double high_price) {
        int tf_idx = GetTimeframeIndex(tf);
        string name = SABAI_SWING_UPPER_PREFIX "H_" +
                      IntegerToString(tf_idx) + "_" +
                      IntegerToString((long)chart_bar_time);
        double anchor = high_price + (double)m_upper_label_offset_pts * _Point;
        UpsertSwingMarker(name, m_upper_high_color, chart_bar_time, anchor, ANCHOR_LOWER);
    }

    void DrawUpperTFSwingLow(const ENUM_TIMEFRAMES tf,
                             const datetime chart_bar_time,
                             const double low_price) {
        int tf_idx = GetTimeframeIndex(tf);
        string name = SABAI_SWING_UPPER_PREFIX "L_" +
                      IntegerToString(tf_idx) + "_" +
                      IntegerToString((long)chart_bar_time);
        double anchor = low_price - (double)m_upper_label_offset_pts * _Point;
        UpsertSwingMarker(name, m_upper_low_color, chart_bar_time, anchor, ANCHOR_UPPER);
    }
};

#endif
