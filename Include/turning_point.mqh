// レンジの転換点を更新する
void update_range_of_turning_point()
{
  if(currentDirectionOfBreakout == "above"){
    lowOfRange = nextTurningLow;
    // Print("★レンジを上に抜けた");
    // Print("★レンジ下限： ", lowOfRange);
    LineMove("low");
    ChartRedraw();
  } else if(currentDirectionOfBreakout == "below") {
    highOfRange = nextTurningHigh;
    // Print("★レンジを下に抜けた");
    // Print("★レンジ上限： ", highOfRange);
    LineMove("high");
    ChartRedraw();
  } else if(currentDirectionOfBreakout == "both") {
    highOfRange = nextTurningHigh;
    lowOfRange = nextTurningLow;
    // Print("！！！find_and_save_turning_point: Logic's fucked up!!!");
    // Print("★レンジをどちらにも抜けた");
    // Print("★レンジ上限： ", highOfRange);
    // Print("★レンジ下限： ", lowOfRange);
    LineMove("high");
    LineMove("low");
    ChartRedraw();
  }
}
