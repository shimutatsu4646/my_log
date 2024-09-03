// 転換点を逆算する
void find_and_save_turning_point()
{
  if(currentDirectionOfBreakout == "above"){
    lowOfRange = find_last_low();
    Print("★レンジを上に抜けた");
    Print("★レンジ下限： ", lowOfRange);
    LineMove("low");
    ChartRedraw();
  } else if(currentDirectionOfBreakout == "below") {
    highOfRange = find_last_high();
    Print("★レンジを下に抜けた");
    Print("★レンジ上限： ", highOfRange);
    LineMove("high");
    ChartRedraw();
  } else if(currentDirectionOfBreakout == "both") {
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！find_and_save_turning_point: Logic's fucked up!!!");
  }
}

// 転換点（高値）を逆算する
double find_last_high()
{
  double last_high;
  // ↓レンジブレイクした足
  double high = iHigh(Symbol(),Period(), 1);
  double low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_high > high){
      // 高値更新
      high = previous_bar_high;
      low = previous_bar_low;
      is_found = false;
    } else {
      // 高値が更新されなかった場合

      if (previous_bar_low < low) {
        // 安値更新
        last_high = high;
        is_found = true;
      } else {
        // はらみ足

        last_high = high;
        is_found = true;
      }
    }
  }

  return last_high;
}

// 転換点（安値）を逆算する
double find_last_low()
{
  double last_low;
  // ↓レンジブレイクした足
  double high = iHigh(Symbol(),Period(), 1);
  double low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_low < low){
      // 安値更新
      high = previous_bar_high;
      low = previous_bar_low;
      is_found = false;
    } else {
      // 安値が更新されなかった場合

      if (previous_bar_high > high) {
        // 高値更新
        last_low = low;
        is_found = true;
      } else {
        // はらみ足

        last_low = low;
        is_found = true;
      }
    }
  }

  return last_low;
}
