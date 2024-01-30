// int current_trend() // 中立：0、上昇トレンド：1、下降トレンド：-1
// {
//   if(previousDirectionOfBreakout != currentDirectionOfBreakout){
//     return 0;
//   } else {
//     if(currentDirectionOfBreakout == "above"){
//       return 1;
//     }else if(currentDirectionOfBreakout == "below"){
//       return -1;
//     }
//   }
// }

// トレンドの中にレンジがある（含まれている）。
// 高値・安値→トレンド中に発生したレンジ内で一番高い高値・一番低い安値
    // トレンド内の足と統合できる？から？
// 上昇トレンド：
  // 高値→高値更新が終わって、一番高い足の高値
  // 安値→直前のレンジ内で一番低いところまで行った足の安値
// 下降トレンド：
  // 高値→直前のレンジ内で一番高いところまで行った足の高値
  // 安値→安値更新が終わって、一番安い足の安値

// 押し目安値は、上昇トレンド中に見られる一時的な価格の下落（押し目）の最低点を指します。
    // →（上昇トレンド内で発生したレンジ内において最も低い価格）
// 戻り高値は、下降トレンド中に見られる一時的な価格の上昇（戻り）の最高点を指します。
    // →（下降トレンド内で発生したレンジ内において最も高い価格）

// 上昇トレンドで、押し安値が更新された
// →上昇トレンド終了。
// しかしまだ下降トレンドでも無い
// →高値が更新しないことが確定した瞬間(更に安値を更新す下降トレンドとなる。



// ＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝


// 注文入れる際の考慮点：
// 逆指値注文のpriceの設定や損切りの設定で、レンジを少し超えたところにしたい
  // price,sl,tpの値を1ポイント増やすには、EUR/USDの場合、0.00001を加える（JPYペアの場合は0.001）。
    // ↓この値(pointValue)をプラスしたりマイナスしたりする。
    // double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

// スリッページ（価格偏差）
  // 注文がリクエストされた価格と異なる価格で執行される現象を指し、
  // 市場の高い変動性や流動性の低さによって引き起こされることがある
  // request.deviation = 3; この場合、3ポイントのスリッページまで許容される。deviation＝（最大価格偏差）
  // 逆指値だと、急速に市場が動いたときに最悪注文が執行されない可能性がある
  // 気持ち広めに許容しておいて良さそう。

//スプレッド
  // 買値と売値の差であり、取引コストの一部と考えることができる。
  // 特に短期取引やスキャルピング戦略を行う場合、スプレッドは利益に大きな影響を与える
  // 逆指値注文であればある程度抑えられる
  // コードで対策できることは特になく、ブローカーの選定（低スプレッドか）などが主な対応になる



ENUM_ORDER_TYPE_FILLING FillPolicy()
{
  long fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  if(fillType==SYMBOL_FILLING_IOC)return ORDER_FILLING_IOC;
  else if(fillType==SYMBOL_FILLING_FOK)return ORDER_FILLING_FOK;
  else return ORDER_FILLING_RETURN;
}