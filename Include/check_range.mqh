// レンジを抜けたか確認する
bool is_range_broken()
{
  // 確定済みの足（最新）
  double latest_bar_high = iHigh(Symbol(),Period(), 1);
  double latest_bar_low = iLow(Symbol(),Period(), 1);
  // 更に一つ前の確定済み足
  double previous_bar_high = iHigh(Symbol(),Period(), 2);
  double previous_bar_low = iLow(Symbol(),Period(), 2);
  bool is_updated = false;

  if(latest_bar_high > highOfRange && latest_bar_low < lowOfRange){
    // レンジを上下どちらにも更新した場合
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "both";
    comparativeHigh = previous_bar_high;
    comparativeLow = previous_bar_low;
    // この足がレンジになる
    highOfRange = latest_bar_high;
    lowOfRange = latest_bar_low;
    Print("★レンジをどちらにも抜けた");
    Print("★レンジ上限： ", highOfRange);
    Print("★レンジ下限： ", lowOfRange);
    LineMove("high");
    LineMove("low");
    ChartRedraw();
  }

  if(is_updated == false && latest_bar_high > highOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "above";
    comparativeHigh = previous_bar_high;
    comparativeLow = previous_bar_low;
  }

  if(is_updated == false && latest_bar_low < lowOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "below";
    comparativeHigh = previous_bar_high;
    comparativeLow = previous_bar_low;
  }

  return is_updated;
}


// レンジが確定したか確認する
bool is_range_confirmed()
{
  double latest_bar_high;
  double latest_bar_low;
  bool is_confirmed;
  // 最新の確定した足
  latest_bar_high = iHigh(Symbol(),Period(), 1);
  latest_bar_low = iLow(Symbol(),Period(), 1);

  if(currentDirectionOfBreakout == "above"){
    // 上抜け中の場合

    if(latest_bar_high > comparativeHigh){
      // 高値更新

      if (latest_bar_low < comparativeLow) {
        // 包み線
        highOfRange = latest_bar_high;
        lowOfRange = latest_bar_low;
        is_confirmed = true;
        Print("★レンジ確定（包み線）");
        Print("レンジ上限： ", highOfRange);
        Print("レンジ下限（更新）： ", lowOfRange);
        LineMove("high");
        LineMove("low");
        ChartRedraw();
      } else {
        comparativeHigh = latest_bar_high;
        comparativeLow = latest_bar_low;
        is_confirmed = false;
      }
    } else {
      // 高値が更新されなかった場合

      if (latest_bar_low < comparativeLow) {
        // 安値更新
        highOfRange = comparativeHigh;
        is_confirmed = true;
        Print("★レンジ確定");
        Print("レンジ上限： ", highOfRange);
        Print("レンジ下限（既出）： ", lowOfRange);
        LineMove("high");
        ChartRedraw();
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合

    if(latest_bar_low < comparativeLow){
      // 安値更新

      if (latest_bar_high > comparativeHigh) {
        // 包み線
        lowOfRange = latest_bar_low;
        highOfRange = latest_bar_high;
        is_confirmed = true;
        Print("★レンジ確定(包み線)");
        Print("レンジ下限： ", lowOfRange);
        Print("レンジ上限（更新）： ", highOfRange);
        LineMove("low");
        LineMove("high");
        ChartRedraw();
      } else {
        // ハラミ足
        is_confirmed = false;
      }
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      is_confirmed = false;
    } else {
      // 安値が更新されなかった場合

      if (latest_bar_high > comparativeHigh) {
        // 高値更新
        lowOfRange = comparativeLow;
        is_confirmed = true;
        Print("★レンジ確定");
        Print("レンジ下限： ", lowOfRange);
        Print("レンジ上限（既出）： ", highOfRange);
        LineMove("low");
        ChartRedraw();
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "both"){
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！is_range_confirmed: Logic's fucked up!!!");
  }

  return is_confirmed;
}
