#ifndef SABAI_SYSTEM_DRAWING_OBJECT_HELPER_MQH
#define SABAI_SYSTEM_DRAWING_OBJECT_HELPER_MQH

#define SABAI_OBJ_PREFIX "SABAI_"

class CObjectHelper {
public:
    static void DeleteByPrefix(const string prefix) {
        for (int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
            string name = ObjectName(0, i, 0, -1);
            if (StringFind(name, prefix) == 0)
                ObjectDelete(0, name);
        }
    }

    static void DeleteAll() {
        DeleteByPrefix(SABAI_OBJ_PREFIX);
    }

    static bool UpsertTextLabel(const string name,
                                const datetime time,
                                const double price,
                                const string text,
                                const color clr,
                                const int font_size = 8,
                                const string font = "Arial",
                                const ENUM_ANCHOR_POINT anchor = ANCHOR_CENTER) {
        if (ObjectFind(0, name) < 0) {
            if (!ObjectCreate(0, name, OBJ_TEXT, 0, time, price))
                return false;
        } else {
            ObjectMove(0, name, 0, time, price);
        }
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetString(0, name, OBJPROP_FONT, font);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        return true;
    }

    static bool UpsertVLine(const string name,
                            const datetime time,
                            const color clr,
                            const int style = STYLE_SOLID,
                            const int width = 1) {
        if (ObjectFind(0, name) < 0) {
            if (!ObjectCreate(0, name, OBJ_VLINE, 0, time, 0))
                return false;
        } else {
            ObjectMove(0, name, 0, time, 0);
        }
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        return true;
    }

    static bool UpsertTrendLine(const string name,
                                const datetime start_time,
                                const double start_price,
                                const datetime end_time,
                                const double end_price,
                                const color clr,
                                const int style = STYLE_SOLID,
                                const int width = 2,
                                const bool ray_right = false) {
        datetime right_time = (end_time > start_time) ? end_time : (start_time + 1);
        if (ObjectFind(0, name) < 0) {
            if (!ObjectCreate(0, name, OBJ_TREND, 0, start_time, start_price, right_time, end_price))
                return false;
        } else {
            ObjectMove(0, name, 0, start_time, start_price);
            ObjectMove(0, name, 1, right_time, end_price);
        }
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, ray_right);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 80);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        return true;
    }

    static bool UpsertHLine(const string name,
                            const datetime start_time,
                            const datetime end_time,
                            const double price,
                            const color clr,
                            const int style = STYLE_SOLID,
                            const int width = 2) {
        return UpsertTrendLine(name, start_time, price, end_time, price,
                               clr, style, width, false);
    }

    static bool UpsertRectangle(const string name,
                                const datetime left_time,
                                const double top_price,
                                const datetime right_time,
                                const double bottom_price,
                                const color clr,
                                const bool fill = true) {
        if (ObjectFind(0, name) < 0) {
            if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                              left_time, top_price, right_time, bottom_price))
                return false;
        } else {
            ObjectMove(0, name, 0, left_time, top_price);
            ObjectMove(0, name, 1, right_time, bottom_price);
        }
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_FILL, fill);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        return true;
    }

    static bool UpsertChartLabel(const string name,
                                 const int x_pixels,
                                 const int y_pixels,
                                 const string text,
                                 const color clr,
                                 const int font_size = 9,
                                 const string font = "Consolas",
                                 const ENUM_BASE_CORNER corner = CORNER_RIGHT_UPPER) {
        if (ObjectFind(0, name) < 0) {
            if (!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
                return false;
        }
        ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_pixels);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_pixels);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetString(0, name, OBJPROP_FONT, font);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 200);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        return true;
    }

    static string MakeName(const string category, const string suffix) {
        return SABAI_OBJ_PREFIX + category + "_" + suffix;
    }

    static string MakeNameWithTime(const string category, const datetime t) {
        return SABAI_OBJ_PREFIX + category + "_" + IntegerToString((long)t);
    }

    static string MakeNameWithTimeAndPrice(const string category,
                                           const datetime t,
                                           const double price) {
        long price_key = (long)MathRound(price / _Point);
        return SABAI_OBJ_PREFIX + category + "_" +
               IntegerToString((long)t) + "_" + IntegerToString(price_key);
    }
};

#endif
