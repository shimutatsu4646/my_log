// 水平線を作成する
bool LineCreate(string state)
{

  // デフォルト値を設定
  long chart_ID = 0; // チャート識別子。（ 0 は現在のチャート）
  int sub_window = 0; // チャートサブウィンドウ番号(0 はメインチャートウィンドウ。指定されたサブウィンドウは存在しなければなりません。さもないと、この関数は false を返します。)
  string name; // 線の名称（オブジェクト名名称は、サブウィンドウを含めたチャート内で一意でなければなりません。）
  double price; // 線の価格
  if (state == "high") {
    name = "HighLine";
    price = highOfRange;
  } else {
    name = "LowLine";
    price = lowOfRange;
  }
  color clr = clrHotPink; // 線の色
  ENUM_LINE_STYLE style = STYLE_SOLID; // 線のスタイル
  int width = 1; // 線の幅
  bool back = false; // 背景で表示する
  bool selection = true; // 強調表示して移動
  bool hidden = true; // オブジェクトリストに隠す
  long z_order = 0; // マウスクリックの優先順位

//--- エラー値をリセットする
  ResetLastError();
//--- 水平線を作成する
  if(!ObjectCreate(chart_ID, name, OBJ_HLINE, sub_window, 0, price))
    {
    Print(__FUNCTION__,
          ": failed to create a horizontal line! Error code = ",GetLastError());
    return(false);
    }
//--- 線の色を設定する
  ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- 線の表示スタイルを設定する
  ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- 線の幅を設定する
  ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- 前景（false）または背景（true）に表示
  ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- マウスで線を移動させるモードを有効（true）か無効（false）にする
//--- ObjectCreate 関数を使用してグラフィックオブジェクトを作成する際、オブジェクトは
//--- デフォルトではハイライトされたり動かされたり出来ない。このメソッド内では、選択パラメータは
//--- デフォルトでは true でハイライトと移動を可能にする。
  ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
  ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- オブジェクトリストのグラフィックオブジェクトを非表示（true）か表示（false）にする
  ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- チャートのマウスクリックのイベントを受信するための優先順位を設定する
  ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- 実行成功
  return(true);
}



// 水平線を移動する
bool LineMove(string state)
{

  long chart_ID = 0;   // チャート識別子
  string name; // 線の名称
  double price; // 線の価格
  if (state == "high") {
    name = "HighLine";
    price = highOfRange;
  } else {
    name = "LowLine";
    price = lowOfRange;
  }

//--- エラー値をリセットする
  ResetLastError();
//--- 水平線を移動する
  if(!ObjectMove(chart_ID, name, 0, 0, price))
    {
    Print(__FUNCTION__,
          ": failed to move the horizontal line! Error code = ",GetLastError());
    return(false);
    }
//--- 実行成功
  return(true);
}


// 水平線を削除する（使用していない）
bool LineDelete(string state)
{
  long chart_ID = 0;   // チャート識別子
  string name;

  if (state == "high") {
    name = "HighLine";
  } else {
    name = "LowLine";
  }
//--- エラー値をリセットする
  ResetLastError();
//--- 水平線を削除する
  if(!ObjectDelete(chart_ID, name))
    {
    Print(__FUNCTION__,
          ": failed to delete a horizontal line! Error code = ",GetLastError());
    return(false);
    }
//--- 実行成功
  return(true);
}
