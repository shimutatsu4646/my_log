// A：高値を更新し、安値を更新せず（安値は同値でも可）
//     上昇方向

// B：安値を更新し、高値を更新せず（高値は同値でも可）
//     下降方向

// C：はらみ足
//     無視する → 前の足と合体させて考える

// D：包み足
//     レンジ相場 → 過去にある転換点との間でレンジ

// comparativeHigh/LowとnextTurningHigh/Lowを更新する
void update_global_bar_data()
{
  // パターンC以外は毎度comparativeの更新あり
  // 直前の足の流れと逆に更新された場合（A,B）と包み足の場合（D）、転換点が導出される

  // 最新の足（確定済み）
  double latest_bar_high = iHigh(Symbol(),Period(), 1);
  double latest_bar_low = iLow(Symbol(),Period(), 1);

  // 最新のbarDirectionは最後に代入する。→前回のbarDirectionを参照できる
  if(latest_bar_high > comparativeHigh){
    if (latest_bar_low < comparativeLow) {
      // パターンD
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      if (barDirection == "above") {
        nextTurningHigh = latest_bar_high;
        // ↓DMA3*3の確認以前に更新が必要なケース
        if (nextTurningLow > latest_bar_low) {
          nextTurningLow = latest_bar_low;
        } else {
          // 最新足の安値がDMA3*3を下抜けている場合
          if (dma3Buffer[0] > latest_bar_low) {
            nextTurningLow = latest_bar_low;
          }
        }
      } else if (barDirection == "below") {
        nextTurningLow = latest_bar_low;
        // ↓DMA3*3の確認以前に更新が必要なケース
        if (nextTurningHigh < latest_bar_high) {
          nextTurningHigh = latest_bar_high;
        } else {
          // 最新足の高値がDMA3*3を上抜けている場合
          if (dma3Buffer[0] < latest_bar_high) {
            nextTurningHigh = latest_bar_high;
          }
        }
      } else if (barDirection == "both") {
        // 基本的にありえない。包み足の次に更に包み足になるということ。
        nextTurningHigh = latest_bar_high;
        nextTurningLow = latest_bar_low;
      }
      barDirection = "both";
    } else {
      // パターンA
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      if (dma3Buffer[0] < latest_bar_high) {
        // DMA3*3を上抜けている場合のみ転換点候補にする
        nextTurningHigh = latest_bar_high;
        // is_range_confirmedではこの条件を入れてない
        // 一旦レンジ確定で区切ったほうが良いと判断
      }
      barDirection = "above";
    }
  } else {
    if (latest_bar_low < comparativeLow) {
      // パターンB
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      if (dma3Buffer[0] > latest_bar_low) {
        // DMA3*3を下抜けている場合のみ転換点候補にする
        nextTurningLow = latest_bar_low;
        // is_range_confirmedではこの条件を入れてない
        // 一旦レンジ確定で区切ったほうが良いと判断
      }
      barDirection = "below";
    } else {
      // パターンC
      // 更新なし
    }
  }
}

// レンジを抜けたか確認する
bool is_range_broken()
{
  // 確定済みの足（最新）
  double latest_bar_high = iHigh(Symbol(),Period(), 1);
  double latest_bar_low = iLow(Symbol(),Period(), 1);
  bool is_updated = false;

  // ↓基本的に発生しない想定。
  if(latest_bar_high > highOfRange && latest_bar_low < lowOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "both";
  }

  if(is_updated == false && latest_bar_high > highOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "above";
  }

  if(is_updated == false && latest_bar_low < lowOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "below";
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
        // パターンD
        if (dma3Buffer[0] > latest_bar_low) {
          // 最新足の安値がDMA3*3を下抜けている場合
          highOfRange = latest_bar_high;
          // lowOfRangeは格納済み（update_range_of_turning_point）
          is_confirmed = true;
          // Print("★レンジ確定（包み足）");
          // Print("レンジ上限： ", highOfRange);
          // Print("レンジ下限： ", lowOfRange);
          LineMove("high");
          ChartRedraw();
        } else {
          // 最新足の安値がDMA3*3を下抜けていない場合
          is_confirmed = false;
        }
      } else {
        // パターンA
        is_confirmed = false;
      }
    } else {
      // 高値が更新されなかった場合
      if (latest_bar_low < comparativeLow) {
        // パターンB
        highOfRange = comparativeHigh;
        is_confirmed = true;
        // Print("★レンジ確定");
        // Print("レンジ上限： ", highOfRange);
        // Print("レンジ下限： ", lowOfRange);
        LineMove("high");
        ChartRedraw();
      } else {
        // パターンC
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合
    if(latest_bar_low < comparativeLow){
      // 安値更新
      if (latest_bar_high > comparativeHigh) {
        // パターンD
        if (dma3Buffer[0] < latest_bar_high) {
          // 最新足の高値がDMA3*3を上抜けている場合
          lowOfRange = latest_bar_low;
          // highOfRangeは格納済み（update_range_of_turning_point）
          is_confirmed = true;
          // Print("★レンジ確定(包み足)");
          // Print("レンジ下限： ", lowOfRange);
          // Print("レンジ上限： ", highOfRange);
          LineMove("low");
          ChartRedraw();
        } else {
          // 最新足の高値がDMA3*3を上抜けていない場合
          is_confirmed = false;
        }
      } else {
        // パターンB
        is_confirmed = false;
      }
    } else {
      // 安値が更新されなかった場合
      if (latest_bar_high > comparativeHigh) {
        // パターンA
        lowOfRange = comparativeLow;
        is_confirmed = true;
        // Print("★レンジ確定");
        // Print("レンジ下限： ", lowOfRange);
        // Print("レンジ上限： ", highOfRange);
        LineMove("low");
        ChartRedraw();
      } else {
        // パターンC
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "both"){
    // current~~がbothのとき、この関数は実行されないはず
    // Print("！！！is_range_confirmed: Logic's fucked up!!!");
  }

  return is_confirmed;
}
