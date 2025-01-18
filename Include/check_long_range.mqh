// ==========================================================

// comparativeLongHigh/LowとnextTurningLongHigh/Lowを更新する
void update_global_long_bar_data()
{
  // パターンC以外は毎度comparativeの更新あり
  // 直前の足の流れと逆に更新された場合（A,B）と包み足の場合（D）、転換点が導出される

  // 最新の足（確定済み）
  double latest_bar_high = iHigh(Symbol(),PERIOD_W1, 1);
  double latest_bar_low = iLow(Symbol(),PERIOD_W1, 1);

  if(latest_bar_high > comparativeLongHigh){
    if (latest_bar_low < comparativeLongLow) {
      // パターンD
      comparativeLongHigh = latest_bar_high;
      comparativeLongLow = latest_bar_low;
      // 包み足は転換点の候補になる
      nextTurningLongHigh = latest_bar_high;
      nextTurningLongLow = latest_bar_low;
      longBarDirection = "both";
    } else {
      // パターンA
      if(longBarDirection == "below") {
        nextTurningLongLow = comparativeLongLow;
      }
      comparativeLongHigh = latest_bar_high;
      comparativeLongLow = latest_bar_low;
      longBarDirection = "above";
    }
  } else {
    if (latest_bar_low < comparativeLongLow) {
      // パターンB
      if(longBarDirection == "above") {
        nextTurningLongHigh = comparativeLongHigh;
      }
      comparativeLongHigh = latest_bar_high;
      comparativeLongLow = latest_bar_low;
      longBarDirection = "below";
    } else {
      // パターンC
      // 更新なし
    }
  }
}

// 長期時間軸の長期レンジを抜けたか確認する
bool is_long_range_broken()
{
  // 確定済みの足（最新）
  double latest_bar_high = iHigh(Symbol(),PERIOD_W1, 1);
  double latest_bar_low = iLow(Symbol(),PERIOD_W1, 1);
  bool is_updated = false;

  if(latest_bar_high > highOfLongRange && latest_bar_low < lowOfLongRange){
    // 長期レンジを上下どちらにも更新した場合
    is_updated = true;
    previousLongDirectionOfBreakout = currentLongDirectionOfBreakout;
    currentLongDirectionOfBreakout = "both";
    // この足が長期レンジになる
    highOfLongRange = latest_bar_high;
    lowOfLongRange = latest_bar_low;
    // update_global_long_bar_data()のパターンDと同様にデータ格納
    comparativeLongHigh = latest_bar_high;
    comparativeLongLow = latest_bar_low;
    nextTurningLongHigh = latest_bar_high;
    nextTurningLongLow = latest_bar_low;
    longBarDirection = "both";
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
  }

  if(is_updated == false && latest_bar_low < lowOfLongRange){
    is_updated = true;
    previousLongDirectionOfBreakout = currentLongDirectionOfBreakout;
    currentLongDirectionOfBreakout = "below";
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
        // パターンD
        highOfLongRange = latest_bar_high;
        is_confirmed = true;
        Print("★長期レンジ確定（包み足）");
        Print("長期レンジ上限： ", highOfLongRange);
        Print("長期レンジ下限： ", lowOfLongRange);
        LongLineMove("high");
        ChartRedraw();
      } else {
        // パターンA
        is_confirmed = false;
      }
    } else {
      // 高値が更新されなかった場合
      if (latest_bar_low < comparativeLongLow) {
        // パターンB
        highOfLongRange = comparativeLongHigh;
        is_confirmed = true;
        Print("★長期レンジ確定");
        Print("長期レンジ上限： ", highOfLongRange);
        Print("長期レンジ下限： ", lowOfLongRange);
        LongLineMove("high");
        ChartRedraw();
      } else {
        // パターンC
        is_confirmed = false;
      }
    }
  } else if(currentLongDirectionOfBreakout == "below"){
    // 下抜け中の場合
    if(latest_bar_low < comparativeLongLow){
      // 安値更新
      if (latest_bar_high > comparativeLongHigh) {
        // パターンD
        lowOfLongRange = latest_bar_low;
        is_confirmed = true;
        Print("★長期レンジ確定(包み足)");
        Print("長期レンジ下限： ", lowOfLongRange);
        Print("長期レンジ上限： ", highOfLongRange);
        LongLineCreate("low");
        ChartRedraw();
      } else {
        // パターンB
        is_confirmed = false;
      }
    } else {
      // 安値が更新されなかった場合
      if (latest_bar_high > comparativeLongHigh) {
        // パターンA
        lowOfLongRange = comparativeLongLow;
        is_confirmed = true;
        Print("★長期レンジ確定");
        Print("長期レンジ下限： ", lowOfLongRange);
        Print("長期レンジ上限： ", highOfLongRange);
        LongLineMove("low");
        ChartRedraw();
      } else {
        // パターンC
        is_confirmed = false;
      }
    }
  } else if(currentLongDirectionOfBreakout == "both"){
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！is_range_confirmed: Logic's fucked up!!!");
  }

  return is_confirmed;
}
