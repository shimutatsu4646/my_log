// 許容できる損失割合をもとにロット数を計算する
double volume_with_risk_manegemant()
{
  // ロット(volume)計算ロジック
    // 許容損失額 / 証拠金 = rate(1%とか) / 100
      // → 許容損失額 = 証拠金 * (rate / 100)
    // 許容損失額 = 損失幅(値幅。1.5円とか0.01500ポンドとか) * ポジションサイズ（通貨数）
      // 円を含む通貨ペアの場合↓
        // → ポジションサイズ = 許容損失額 / 損失幅
      // 円を含まない通貨ペアの場合↓
        // → ポジションサイズ = 許容損失額 / 損失幅 / 決済通貨の対円レート（右側の通貨）
  // ★ volume = ポジションサイズ / 1スタンダードロット（単位）

  int digits = Digits();
  // 証拠金に対する損失額の割合（X %）
  double rate = 5.0;
  // 有効証拠金
  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  // long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
  // double effective_equity = equity * leverage;
  // 許容損失額
  double loss_amount = equity * (rate / 100);
  // double loss_amount = effective_equity * (rate / 100);
  loss_amount = NormalizeDouble(loss_amount, digits);

  double price = request.price;
  double sl = request.sl;
  // 損失幅（値幅） = price - sl => 絶対値
  double loss_extent = MathAbs(price - sl);
  loss_extent = NormalizeDouble(loss_extent, digits);
  // ポジションサイズ
  double position_size = loss_amount / loss_extent;
  // Print("loss_amount", loss_amount);
  // Print("loss_extent", loss_extent);
  // Print("position_size", position_size);

  // 通貨ペアのうちの決済通貨を抽出
  string symbol = Symbol();
  string settlement_currency;
  int length = StringLen(symbol);
  if(length > 3) {
  // if(length == 6) { // こっちのほうが良さそう
    // 最初の3文字を取り除いて残りの文字列を取得
    settlement_currency = StringSubstr(symbol, 3, length - 3);
  } else {
    // 元の文字列が3文字以下の場合は、空の文字列を返す
    settlement_currency = "";
  }

  if (settlement_currency != "JPY") {
    // 円を含まない通貨ペアの場合↓
       // 決済通貨の対円レート（右側の通貨）で割る
    string current_with_jpy = settlement_currency;
    StringAdd(current_with_jpy, "JPY");

    MqlTick tick;
    double symbol_rate;
    // 最新のティックデータを取得
    if(SymbolInfoTick(current_with_jpy, tick)){
      // ask価格とbid価格の平均を取得して対円レートとして使用
      symbol_rate = (tick.ask + tick.bid) / 2.0;
      position_size = position_size / symbol_rate;
    }
    else{
      // データ取得に失敗した場合のエラーメッセージ
      // TODO: GetLastError();
    }
    // 整数に丸める（ほんとに必要？）
    position_size = MathRound(position_size);
  }

  double amount_currency_of_one_lot = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
  double volume = position_size / amount_currency_of_one_lot;
  // Print("amount_currency_of_one_lot", amount_currency_of_one_lot);
  // Print("before volume", volume);

  // CHECK: SYMBOL_TRADE_CONTRACT_SIZEが実際のロット数と一致しないケースあり。
  volume = verify_volume(volume);
  // Print("after volume", volume);
  return volume;
}

// 不正なロット数にならないように修正する
double verify_volume(double volume)
{

  double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
	double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
	double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

	double tradeSize;
	if(volume < minVolume){
    tradeSize = minVolume;
  } else if(volume > maxVolume) {
    tradeSize = maxVolume;
  } else {
  // ブローカーが規定しているステップ幅に応じたロット数に修正
  // 参照：https://mqlinvestmentlab.com/mql5lesson101/#toc18
  // MathRoundは、引数の値を最も近い整数に丸める
   tradeSize = MathRound(volume / stepVolume) * stepVolume;
  }

  // 念のため再度ステップ幅に応じて正規化
	if(stepVolume >= 0.1){
    tradeSize = NormalizeDouble(tradeSize, 1);
  } else {
    tradeSize = NormalizeDouble(tradeSize, 2);
  }

	return(tradeSize);
}

// 実行レバレッジを計算して出力する
void check_effective_leverage()
{
  double totalTradeAmount = 0.0;
  int totalPositions = PositionsTotal();
  double amount_currency_of_one_lot = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);

  for(int i = 0; i < totalPositions; i++)
  {
    ulong position_ticket = PositionGetTicket(i);
    Print("ポジションチケット: ", position_ticket);
    double volume = PositionGetDouble(POSITION_VOLUME);
    Print("ロット: ", volume);
    double price = PositionGetDouble(POSITION_PRICE_OPEN);
    Print("値段: ", price);
    totalTradeAmount += volume * amount_currency_of_one_lot  * price;
  }
  Print("総取引金額", totalTradeAmount);

  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  double effective_leverage = totalTradeAmount / equity;
  Print("実効レバレッジ: ",  effective_leverage);
  if (effective_leverage >= 10){
    Print("！！！！！実効レバレッジが10倍以上！！！！！");
  }
}
