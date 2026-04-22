#ifndef SABAI_SYSTEM_DRAWING_INFO_PANEL_MQH
#define SABAI_SYSTEM_DRAWING_INFO_PANEL_MQH

#include "../Types.mqh"
#include "ObjectHelper.mqh"

#define SABAI_PANEL_PREFIX SABAI_OBJ_PREFIX "PN_"
#define SABAI_PANEL_FONT   "Consolas"
#define SABAI_PANEL_SIZE   9

class CInfoPanel {
private:
    int m_x_offset;
    int m_y_start;
    int m_line_height;

    color GetPhaseColor(const MarketPhase phase) {
        switch (phase) {
            case PHASE_UP_TREND:    return clrLimeGreen;
            case PHASE_DOWN_TREND:  return clrRed;
            case PHASE_RANGE:       return clrOrange;
            case PHASE_RANDOM:      return clrGray;
            default:                return clrDarkGray;
        }
    }

    color GetBiasColor(const BiasDirection dir) {
        switch (dir) {
            case BIAS_BULLISH: return clrLimeGreen;
            case BIAS_BEARISH: return clrRed;
            default:           return clrGray;
        }
    }

    string PadRight(const string text, const int total_len) {
        string result = text;
        while (StringLen(result) < total_len)
            result += " ";
        return result;
    }

public:
    void Init(const int x_offset = 20,
              const int y_start = 25,
              const int line_height = 18) {
        m_x_offset   = x_offset;
        m_y_start    = y_start;
        m_line_height = line_height;
    }

    void Clear() {
        CObjectHelper::DeleteByPrefix(SABAI_PANEL_PREFIX);
    }

    void DrawHeader() {
        string name = SABAI_PANEL_PREFIX "HDR";
        string text = PadRight("TF", 5) + PadRight("Phase", 13) + "SlowBias";
        CObjectHelper::UpsertChartLabel(name, m_x_offset, m_y_start,
                                        text, clrWhite, SABAI_PANEL_SIZE,
                                        SABAI_PANEL_FONT, CORNER_LEFT_UPPER);
    }

    void DrawTimeframeRow(const int row_index,
                          const ENUM_TIMEFRAMES tf,
                          const MarketPhase phase,
                          const BiasDirection slow_bias) {
        int y = m_y_start + m_line_height * (row_index + 1);
        string tf_label    = GetTimeframeLabel(tf);
        string phase_label = MarketPhaseToString(phase);
        string bias_label  = BiasDirectionToString(slow_bias);

        string name_phase = SABAI_PANEL_PREFIX "R" + IntegerToString(row_index) + "P";
        string text_phase = PadRight(tf_label + ":", 5) + PadRight(phase_label, 13);
        CObjectHelper::UpsertChartLabel(name_phase, m_x_offset, y,
                                        text_phase, GetPhaseColor(phase),
                                        SABAI_PANEL_SIZE, SABAI_PANEL_FONT,
                                        CORNER_LEFT_UPPER);

        string name_bias = SABAI_PANEL_PREFIX "R" + IntegerToString(row_index) + "B";
        int bias_x = m_x_offset + 235;
        CObjectHelper::UpsertChartLabel(name_bias, bias_x, y,
                                        bias_label, GetBiasColor(slow_bias),
                                        SABAI_PANEL_SIZE, SABAI_PANEL_FONT,
                                        CORNER_LEFT_UPPER);
    }

    void Update(const TimeframeState &states[], const int count) {
        Clear();
        DrawHeader();
        for (int i = 0; i < count && i < SABAI_MAX_TF_COUNT; i++) {
            DrawTimeframeRow(i, states[i].timeframe,
                             states[i].current_phase,
                             states[i].slow_bias.direction);
        }
    }
};

#endif
