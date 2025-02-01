// 長期レンジの転換点を更新する
void update_long_range_of_turning_point()
{
  if(currentLongDirectionOfBreakout == "above"){
    lowOfLongRange = nextTurningLongLow;
    // Print("★長期レンジを上に抜けた");
    // Print("★長期レンジ下限： ", lowOfLongRange);
    LongLineMove("low");
    ChartRedraw();
  } else if(currentLongDirectionOfBreakout == "below") {
    highOfLongRange = nextTurningLongHigh;
    // Print("★長期レンジを下に抜けた");
    // Print("★長期レンジ上限： ", highOfLongRange);
    LongLineMove("high");
    ChartRedraw();
  } else if(currentLongDirectionOfBreakout == "both") {
    highOfLongRange = nextTurningLongHigh;
    lowOfLongRange = nextTurningLongLow;
    // current~~がbothのとき、この関数は実行されないはず
    // Print("！！！find_and_save_turning_point: Logic's fucked up!!!");
    // Print("★長期レンジ上限： ", highOfLongRange);
    // Print("★長期レンジ下限： ", lowOfLongRange);
    LongLineMove("high");
    LongLineMove("low");
    ChartRedraw();
  }
}
