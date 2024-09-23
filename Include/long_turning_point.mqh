// 転換点を逆算する（長期時間軸）
void find_and_save_long_turning_point()
{
  if(currentLongDirectionOfBreakout == "above"){
    lowOfLongRange = find_last_long_low();
    Print("★長期レンジを上に抜けた");
    Print("★長期レンジ下限： ", lowOfLongRange);
    LongLineMove("low");
    ChartRedraw();
  } else if(currentLongDirectionOfBreakout == "below") {
    highOfLongRange = find_last_long_high();
    Print("★長期レンジを下に抜けた");
    Print("★長期レンジ上限： ", highOfLongRange);
    LongLineMove("high");
    ChartRedraw();
  } else if(currentLongDirectionOfBreakout == "both") {
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！find_and_save_turning_point: Logic's fucked up!!!");
  }
}

// 転換点（高値）を逆算する（長期時間軸）
double find_last_long_high()
{
  double last_high;
  // ↓長期レンジをブレイクした足
  double next_bar_high = iHigh(Symbol(),PERIOD_W1, 1);
  double next_bar_low = iLow(Symbol(),PERIOD_W1, 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),PERIOD_W1, i);
    previous_bar_low = iLow(Symbol(),PERIOD_W1, i);

    if(previous_bar_high > next_bar_high){
      // 高値更新（逆算）
      next_bar_high = previous_bar_high;
      next_bar_low = previous_bar_low;
      is_found = false;
    } else {
      // 高値が更新されなかった場合（逆算）

      if (previous_bar_low < next_bar_low) {
        // 安値更新（逆算）
        last_high = next_bar_high;
        is_found = true;
      } else {
        // next_bar == 包み線

        last_high = next_bar_high;
        is_found = true;
      }
    }
  }

  return last_high;
}

// 転換点（安値）を逆算する（長期時間軸）
double find_last_long_low()
{
  double last_low;
  // ↓長期レンジをブレイクした足
  double next_bar_high = iHigh(Symbol(),PERIOD_W1, 1);
  double next_bar_low = iLow(Symbol(),PERIOD_W1, 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),PERIOD_W1, i);
    previous_bar_low = iLow(Symbol(),PERIOD_W1, i);

    if(previous_bar_low < next_bar_low){
      // 安値更新（逆算）
      next_bar_high = previous_bar_high;
      next_bar_low = previous_bar_low;
      is_found = false;
    } else {
      // 安値が更新されなかった場合（逆算）

      if (previous_bar_high > next_bar_high) {
        // 高値更新（逆算）
        last_low = next_bar_low;
        is_found = true;
      } else {
        // next_bar == 包み線
        last_low = next_bar_low;
        is_found = true;
      }
    }
  }

  return last_low;
}
