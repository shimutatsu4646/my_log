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
  double next_bar_high = iHigh(Symbol(),Period(), 1);
  double next_bar_low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_high > next_bar_high){
      // 高値更新（逆算）
        // next_bar_lowがはらみ足の場合でも、previous_barと合体して考える
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

        // TODO: 更に1個前の足(past_bar)から見てprevious_barがはらみ線の場合→2つの足を一つにまとめて考えるので、next_barは包み線にはならず、上昇トレンド継続となる。(それでもnext_barがpast_barの包み線になる場合はトレンドが一度途切れていることになる。)
            // find_last_lowも同様。別時間軸の関数にも反映。

        // 実装：この中でloopしてnext_barが包み線なのか確認。loopした分だけiをインクリメントすることで整合性を合わせる。

        // 懸念点：レンジが広くなるので、トレンドの勢いがあるときはロット数が減って利益が減る。
          // 逆に無駄な損失を減らして利益が増えるかも

        last_high = next_bar_high;
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
  double next_bar_high = iHigh(Symbol(),Period(), 1);
  double next_bar_low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_low < next_bar_low){
      // 安値更新（逆算）
        // next_bar_lowがはらみ足の場合でも、previous_barと合体して考える
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
