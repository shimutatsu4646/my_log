// レンジを抜けたか確認する
bool is_range_broken()
{
  // 確定済みの足（最新）
  double latest_bar_high = iHigh(Symbol(),Period(), 1);
  double latest_bar_low = iLow(Symbol(),Period(), 1);
  // TODO: comparativeHigh, Lowの代入のロジックをそのうち見直す
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
        // latest_bar == 包み線
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
        // latest_bar == はらみ線
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合

    if(latest_bar_low < comparativeLow){
      // 安値更新

      if (latest_bar_high > comparativeHigh) {
        // latest_bar == 包み線
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
        comparativeHigh = latest_bar_high;
        comparativeLow = latest_bar_low;
        is_confirmed = false;
      }
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
        // latest_bar == はらみ線
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "both"){
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！is_range_confirmed: Logic's fucked up!!!");
  }

  return is_confirmed;
}

// レンジブレイクが止まったのが週足レンジの手前かどうか
bool is_stalled_near_week_range() {
  // 週足レンジ全体の<90%>を超えているところで日足レンジブレイクが止まっていたらtrueを返す
  bool result = false;
  double rate = 90.0;
  double price_range;
  double price_range_with_rate;
  double check_price;
  int digits = Digits();

  price_range = highOfLongRange - lowOfLongRange;
  price_range_with_rate = price_range * (rate / 100);
  price_range_with_rate = NormalizeDouble(price_range_with_rate, digits);

  if (currentDirectionOfBreakout == "above") {
    check_price =  lowOfLongRange + price_range_with_rate;
    if (highOfRange > check_price && highOfRange <= highOfLongRange) {
      result = true;
    } else {
      result = false;
    }
  } else if (currentDirectionOfBreakout == "below") {
    check_price =  highOfLongRange - price_range_with_rate;
    if (lowOfRange < check_price  && lowOfRange >= lowOfLongRange) {
      result = true;
    } else {
      result = false;
    }
  }

  return result;
}
