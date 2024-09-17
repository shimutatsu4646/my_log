// ==========================================================

// 長期時間軸の長期レンジを抜けたか確認する
bool is_long_range_broken()
{
  // 確定済みの足（最新）
  double latest_bar_high = iHigh(Symbol(),PERIOD_W1, 1);
  double latest_bar_low = iLow(Symbol(),PERIOD_W1, 1);
  // 更に一つ前の確定済み足
  double previous_bar_high = iHigh(Symbol(),PERIOD_W1, 2);
  double previous_bar_low = iLow(Symbol(),PERIOD_W1, 2);
  bool is_updated = false;

  if(latest_bar_high > highOfLongRange && latest_bar_low < lowOfLongRange){
    // 長期レンジを上下どちらにも更新した場合
    is_updated = true;
    previousLongDirectionOfBreakout = currentLongDirectionOfBreakout;
    currentLongDirectionOfBreakout = "both";
    comparativeLongHigh = previous_bar_high;
    comparativeLongLow = previous_bar_low;
    // この足が長期レンジになる
    highOfLongRange = latest_bar_high;
    lowOfLongRange = latest_bar_low;
    Print("★長期レンジをどちらにも抜けた");
    Print("★長期レンジ上限： ", highOfLongRange);
    Print("★長期レンジ下限： ", lowOfLongRange);
    LongLineMove("high");
    LongLineMove("low");
    ChartRedraw();
  }

  if(is_updated == false && latest_bar_high > highOfLongRange){
    is_updated = true;
    previousLongDirectionOfBreakout = currentLongDirectionOfBreakout;
    currentLongDirectionOfBreakout = "above";
    comparativeLongHigh = previous_bar_high;
    comparativeLongLow = previous_bar_low;
  }

  if(is_updated == false && latest_bar_low < lowOfLongRange){
    is_updated = true;
    previousLongDirectionOfBreakout = currentLongDirectionOfBreakout;
    currentLongDirectionOfBreakout = "below";
    comparativeLongHigh = previous_bar_high;
    comparativeLongLow = previous_bar_low;
  }

  return is_updated;
}


// 長期時間軸の長期レンジが確定したか確認する
bool is_long_range_confirmed()
{
  double latest_bar_high;
  double latest_bar_low;
  bool is_confirmed;
  // 最新の確定した足
  latest_bar_high = iHigh(Symbol(),PERIOD_W1, 1);
  latest_bar_low = iLow(Symbol(),PERIOD_W1, 1);

  if(currentLongDirectionOfBreakout == "above"){
    // 上抜け中の場合

    if(latest_bar_high > comparativeLongHigh){
      // 高値更新

      if (latest_bar_low < comparativeLongLow) {
        // 包み線
        highOfLongRange = latest_bar_high;
        lowOfLongRange = latest_bar_low;
        is_confirmed = true;
        Print("★長期レンジ確定（包み線）");
        Print("長期レンジ上限： ", highOfLongRange);
        Print("長期レンジ下限（更新）： ", lowOfLongRange);
        LongLineMove("high");
        LongLineMove("low");
        ChartRedraw();
      } else {
        comparativeLongHigh = latest_bar_high;
        comparativeLongLow = latest_bar_low;
        is_confirmed = false;
      }
    } else {
      // 高値が更新されなかった場合

      if (latest_bar_low < comparativeLongLow) {
        // 安値更新
        highOfLongRange = comparativeLongHigh;
        is_confirmed = true;
        Print("★長期レンジ確定");
        Print("長期レンジ上限： ", highOfLongRange);
        Print("長期レンジ下限（既出）： ", lowOfLongRange);
        LongLineMove("high");
        ChartRedraw();
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentLongDirectionOfBreakout == "below"){
    // 下抜け中の場合

    if(latest_bar_low < comparativeLongLow){
      // 安値更新

      if (latest_bar_high > comparativeLongHigh) {
        // 包み線
        lowOfLongRange = latest_bar_low;
        highOfLongRange = latest_bar_high;
        is_confirmed = true;
        Print("★長期レンジ確定(包み線)");
        Print("長期レンジ下限： ", lowOfLongRange);
        Print("長期レンジ上限（更新）： ", highOfLongRange);
        LongLineMove("low");
        LongLineMove("high");
        ChartRedraw();
      } else {
        // ハラミ足
        is_confirmed = false;
      }
      comparativeLongHigh = latest_bar_high;
      comparativeLongLow = latest_bar_low;
      is_confirmed = false;
    } else {
      // 安値が更新されなかった場合

      if (latest_bar_high > comparativeLongHigh) {
        // 高値更新
        lowOfLongRange = comparativeLongLow;
        is_confirmed = true;
        Print("★長期レンジ確定");
        Print("長期レンジ下限： ", lowOfLongRange);
        Print("長期レンジ上限（既出）： ", highOfLongRange);
        LongLineMove("low");
        ChartRedraw();
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentLongDirectionOfBreakout == "both"){
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！is_range_confirmed: Logic's fucked up!!!");
  }

  return is_confirmed;
}
