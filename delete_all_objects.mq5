#property script_show_inputs

input bool InputDeleteAll = true; // true: 全オブジェクト削除 / false: SABAI_プレフィクスのみ

void OnStart() {
    int total = ObjectsTotal(0, 0, -1);
    if (total <= 0) {
        Print("削除対象のオブジェクトはありません。");
        return;
    }

    int deleted = 0;

    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, -1);
        if (InputDeleteAll) {
            ObjectDelete(0, name);
            deleted++;
        } else {
            if (StringFind(name, "SABAI_") == 0 ||
                StringFind(name, "SWING_") == 0) {
                ObjectDelete(0, name);
                deleted++;
            }
        }
    }

    PrintFormat("オブジェクト削除完了: %d / %d 件", deleted, total);
    ChartRedraw(0);
}
