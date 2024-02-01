//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// 自分で定義した関数と関数内で定義した変数は、snake_caseにする。

input double high; // 高値
input double low; // 安値
// ↓今回、レンジのどちらに抜けたか
input string current_direction_of_breakout; // [current] below=下抜け、avobe=上抜け
// ↓前のレンジ抜けの方向
input string previous_direction_of_breakout; // [previous] below=下抜け、avobe=上抜け

input ulong expertMagic = 10;
// global variables
double highOfRange; // 高値
double lowOfRange; // 安値
string currentDirectionOfBreakout;
string previousDirectionOfBreakout;
bool isInRange;
int pyramidingCount;
MqlTradeRequest request;
MqlTradeResult result;

int OnInit()
{
  Print("start ea (OnInit)");
  highOfRange = high;
  lowOfRange = low;
  currentDirectionOfBreakout = current_direction_of_breakout;
  previousDirectionOfBreakout = previous_direction_of_breakout;
  pyramidingCount = 0;
  send_order_both_stop_buy_and_stop_sell();
  isInRange = true;
  return(INIT_SUCCEEDED);
}

void OnTick()
{
  ZeroMemory(request);
  ZeroMemory(result);

  if(isInRange){
    // レンジブレイクしていなければ終了
    if(!is_range_broken()) return;
    // 残留している逆指値注文をキャンセル
    cancel_opposite_order();
    // 前回のブレイク方向とは逆側にブレイクした場合
    if(previousDirectionOfBreakout != currentDirectionOfBreakout) {
      close_opposite_positions();
      // 今格納されている値がそのまま、押し目安値or戻り高値になるため、押し目安値or戻り高値を更新するロジックは不要
      pyramidingCount = 1;
    } else {
      // 上抜けの場合：押し目安値、 下抜けの場合：戻り高値 を導出し、grobal変数に格納
      find_and_save_turning_point();
      // ⑦：全てのポジションの損切り注文を更新する
      update_all_stop_loss();
      pyramidingCount += 1;
    }

    isInRange = false; // レンジブレイクしたためレンジ内ではない
    return; // このタイミングでは高値・安値が確定していない（④）
  }

  if(!isInRange){
    // ④：天井or底が確定するのを待つ(更新が終わるのを待つ)
      // 更新されていたら（＝レンジが確定していないなら）：終了
      // 更新されなかったら（レンジが確定したなら）：再度レンジ導出(B)
    if(!is_range_confirmed()) return;

    // ⑥：新規の逆指値注文をレンジBの上下に入れる。
      // 位置や損切りは②と同じ
    send_order_both_stop_buy_and_stop_sell();
    isInRange = true; // レンジが確定したためレンジ内である
  }
}

// ==============================================================================================
// ==============================================================================================


// ↓レンジ確認 =================================================================================


// 値が格納されるglobal変数
    // previousDirectionOfBreakout
    // currentDirectionOfBreakout
bool is_range_broken()
{
  // 一旦、レンジの幅を超えてたらレンジブレイク確定というロジックにする。
    // TODO: スリッページのせいで注文が執行されない問題が発生したら
    // →注文が執行されていたらレンジブレイク確定というロジックに変更する。
  double previous_high = iHigh(Symbol(),Period(), 1);
  double previous_low = iLow(Symbol(),Period(), 1);
  bool is_updated;

  if(previous_high > highOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "above";
  } else {
    is_updated = false;
  }

  // ↓レンジの上下を同時に更新するのは考えにくいため
  if(is_updated == false ){
    if(previous_low < lowOfRange){
      is_updated = true;
      previousDirectionOfBreakout = currentDirectionOfBreakout;
      currentDirectionOfBreakout = "below";
    } else {
      is_updated = false;
    }
  }

  return is_updated;
}


// 値が格納されるglobal変数
    // 天井or底
bool is_range_confirmed()
{
  double previous_high;
  double second_last_high;
  double previous_low;
  double second_last_low;
  bool is_confirmed;
  if(currentDirectionOfBreakout == "above"){
    // 上抜け中の場合
    previous_high = iHigh(Symbol(),Period(), 1);
    second_last_high = iHigh(Symbol(),Period(), 2);
    if(previous_high < second_last_high){
      // 高値が更新されなかった
      highOfRange = second_last_high;
      is_confirmed = true;
    } else {
      is_confirmed = false;
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合
    previous_low = iLow(Symbol(),Period(), 1);
    second_last_low = iLow(Symbol(),Period(), 2);
    if(previous_low > second_last_low){
      // 安値が更新されなかった
      lowOfRange = second_last_low;
      is_confirmed = true;
    } else {
      is_confirmed = false;
    }
  }
  return is_confirmed;
}

// 値が格納されるglobal変数
    // 押し安値or戻り高値
void find_and_save_turning_point()
{
  int index;
  int previous_peak_index;
  int previous_bottom_index;
  if(currentDirectionOfBreakout == "above"){
    previous_peak_index = count_bars_from_previous_peak_or_bottom();
    index = iLowest(Symbol(), Period(), MODE_LOW, previous_peak_index, 1);
    lowOfRange = iLow(Symbol(),Period(), index + 1);
  } else {
    previous_bottom_index = count_bars_from_previous_peak_or_bottom();
    index = iHighest(Symbol(), Period(), MODE_HIGH, previous_bottom_index, 1);
    highOfRange = iHigh(Symbol(),Period(), index + 1);
  }
}

int count_bars_from_previous_peak_or_bottom()
{
  // TODO: データ型とかのせいで、小数点の値がズレたりしてるかも
  int index;
  bool is_not_found=true;

  if(currentDirectionOfBreakout == "above"){
    // 天井までの足の数
    double high;
    // 直前の確定済み足から始める→ i = 1;
    for(int i = 1; is_not_found; i++)
    {
      high = iHigh(Symbol(),Period(), index);
      if(high == highOfRange){
        index = i;
        is_not_found = false;
      }
    }
  } else {
    // 底までの足の数
    double low;
    // 直前の確定済み足から始める→ i = 1;
    for(int i = 1; is_not_found; i++)
    {
      low = iLow(Symbol(),Period(), index);
      if(low== lowOfRange){
        index = i;
        is_not_found = false;
      }
    }
  }
  return index;
}

// ==============================================================================================
// ↓逆指値注文 =================================================================================

void send_order_both_stop_buy_and_stop_sell()
{
  ZeroMemory(request);
  ZeroMemory(result);
  // ②：①の上限と下限に逆指値注文を置く
    // 上限・下限を少し超えた位置にする
    // 注文はそれぞれレンジの反対側で損切りするように設定する

  //--- 操作パラメータの設定
  request.action = TRADE_ACTION_PENDING;
  request.symbol = Symbol();
  request.deviation = 5;
  request.magic = expertMagic;
  double price;
  double sl;
  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  // double point = Point();
  int digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); // 小数点以下の桁数（精度）
  // int digits = Digits();

  // buy_stop //--- 操作パラメータの設定
  request.type = ORDER_TYPE_BUY_STOP;
  price = highOfRange + point;
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  sl = lowOfRange - point;
  request.sl = NormalizeDouble(sl, digits); // ★チェック
  request.volume = volume_with_risk_manegemant();
  if(!OrderSend(request,result)){
    print_error_of_send_order("buy_stop");
  }
  print_information_of_send_error("buy_stop");

  // sell_stop //--- 操作パラメータの設定
  ZeroMemory(result); // requestは初期化せず使い回す
  request.type = ORDER_TYPE_SELL_STOP;
  price = lowOfRange - point;
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  sl = highOfRange + point;
  request.sl = NormalizeDouble(sl, digits); // ★チェック
  if(!OrderSend(request,result)){
    print_error_of_send_order("sell_stop");
  }
  print_information_of_send_error("sell_stop");
}

// ==============================================================================================
// ↓注文・ポジションの更新/キャンセル/決済 =====================================================

void update_all_stop_loss() // TODO: 動作確認
{
  ZeroMemory(request);
  ZeroMemory(result);
  // 今ある全てのpositionsの損切りを更新する。
    // sl→上抜けの場合：押し目安値、 下抜けの場合：戻り高値  に更新する
    // →currentDirectionOfBreakoutの値に合わせてlow_・high_のどちらの値をslにするかを変える

  int total=PositionsTotal();
  for(int i=0; i<total; i++)
  {
    ulong position_ticket = PositionGetTicket(i);
    ulong magic = PositionGetInteger(POSITION_MAGIC); // ポジションのMagicNumber
    if(magic != expertMagic) continue; // MagicNumberが一致していない場合スキップ

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    double sl;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // positionのsymbolにしてないけど、magicチェックしてるし平気でしょ
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS); // 小数点以下の桁数
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // ポジションタイプ

    ZeroMemory(request);
    ZeroMemory(result);
    //--- 操作パラメータの設定
    request.action = TRADE_ACTION_SLTP;
    request.position = position_ticket;
    request.symbol = position_symbol;

    if(type == POSITION_TYPE_BUY && currentDirectionOfBreakout == "above") // 一致するはず
    {
      sl = lowOfRange - point;
      request.sl = NormalizeDouble(sl, digits);
    } else if(type == POSITION_TYPE_SELL && currentDirectionOfBreakout == "below")  {
      sl = highOfRange + point;
      request.sl = NormalizeDouble(sl, digits);
    } else {
      Print("！！！update_all_stop_loss Error: ポジションのタイプとレンジブレイク方向が一致していない");
    }
    // request.tp = tp; // これはいらないはずだが、リクエストになければどうなるのか。。
    request.magic = expertMagic;
    //--- リクエストの送信
    if(!OrderSend(request,result)){
      print_error_of_send_order("update_all_stop_loss");
    }
    print_information_of_send_error("update_all_stop_loss");
  }
}

void cancel_opposite_order()
{
  int same_magic_count = 0;
  int total = OrdersTotal(); // ←未決注文しか取得しない
  for(int i = total - 1; i >= 0; i--)
  {
    ulong order_ticket = OrderGetTicket(i);
    ulong magic = OrderGetInteger(ORDER_MAGIC);
    if(magic!=expertMagic) continue; // MagicNumberが一致していない場合スキップ

    same_magic_count++;
    ZeroMemory(request);
    ZeroMemory(result);
    request.action = TRADE_ACTION_REMOVE;
    request.order = order_ticket;
    // 残留した未決注文をキャンセル
    if(!OrderSend(request,result)){
      print_error_of_send_order("cancel_opposite_order");
    }
    print_information_of_send_error("cancel_opposite_order");
  }

  // magic_number（適応されているペア）内に逆指値注文は１つだけのはず
    // 片方はポジションになったため
  if(same_magic_count > 1){
    Print("！！！cancel_opposite_order Error：レンジブレイクしたのに未決注文が2つ以上存在している");
    Print("未決注文数:", same_magic_count);
  }
}

void close_opposite_positions()
{
  ENUM_POSITION_TYPE type_of_position_closing;
  if(previousDirectionOfBreakout == "above")
  {
    type_of_position_closing = POSITION_TYPE_BUY;
  } else if(previousDirectionOfBreakout == "below")
  {
    type_of_position_closing = POSITION_TYPE_SELL;
  }

  int total = PositionsTotal();
  for(int i = total - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    ulong magic = PositionGetInteger(POSITION_MAGIC);
    if(magic != expertMagic) continue; // MagicNumberが一致していない場合スキップ

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    if(type != type_of_position_closing) continue; // type一致しない場合、削除対象のポジションではないためスキップ

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS);
    double volume = PositionGetDouble(POSITION_VOLUME);
    ZeroMemory(request);
    ZeroMemory(result);
    request.action = TRADE_ACTION_DEAL;
    request.position = position_ticket;
    request.symbol = position_symbol;
    request.volume = volume;
    request.deviation = 5; // 最大許容偏差＝スリッページ（値はポイント）
    request.magic = expertMagic;
    //--- ポジションタイプによる注文タイプと価格の設定
    if(type == POSITION_TYPE_BUY)
    {
      request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
      request.type =ORDER_TYPE_SELL;
    } else {
      request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
      request.type =ORDER_TYPE_BUY;
    }
    // 決済
    if(!OrderSend(request,result)){
      print_error_of_send_order("close_opposite_positions");
    }
    print_information_of_send_error("close_opposite_positions");
  }
}

// ==============================================================================================
// ↓Print共通化 ================================================================================

void print_error_of_send_order(string function_name)
{
  PrintFormat("！！！OrderSend(%s) Error: %d", function_name, GetLastError()); // リクエストの送信に失敗した場合、エラーコードを出力
  ResetLastError(); // GetLastError()で_LastErrorの値が変更されているためリセット
}

void print_information_of_send_error(string function_name)
{
  PrintFormat("OrderSend(%s): retcode=%u  deal=%I64u  order=%I64u", function_name, result.retcode, result.deal, result.order);
}

// ==============================================================================================
// ↓資産管理 ===================================================================================

double volume_with_risk_manegemant() // TODO: JPYが絡むペア、絡まないペアで計算が異なるためロジック見直し & とりあえずvolumeの値をprintする。
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
  // ピラミッディングの回数でrateを変える
  double rate = rate_by_count_of_pyramiding();
  // 証拠金;
  double margin = AccountInfoDouble(ACCOUNT_BALANCE);
  // 許容損失額
  double loss_amount = margin * (rate / 100);
  loss_amount = NormalizeDouble(loss_amount, digits);

  double price = request.price;
  double sl = request.sl;
  // 損失幅（値幅） = price - sl => 絶対値
  double loss_extent = MathAbs(price - sl);
  loss_extent = NormalizeDouble(loss_extent, digits);
  // ポジションサイズ
  double position_size = loss_amount / loss_extent;

  // 通貨ペアのうちの決済通貨を抽出
  string symbol = Symbol();
  // TODO: 別の関数にしてリファクタ
  string settlement_currency;
  int length = StringLen(symbol);
  // 最初の3文字を取り除いて残りの文字列を取得
  if(length > 3) {
  // if(length == 6) { TODO: これのほうが安全では？
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
    }
    else{
      // データ取得に失敗した場合のエラーメッセージ
      Print("対円レートの取得に失敗しました。");
      // TODO: GetLastError();
    }
    position_size = position_size / symbol_rate;
    // 整数に丸める（ほんとに必要？）
    position_size = MathRound(position_size);
    Print("position_size: ", position_size);
  }

  double amount_currency_of_one_lot = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
  double volume = position_size / amount_currency_of_one_lot;
  volume = verify_volume(volume);
  Print("volume: ", volume);
  return volume;
}

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

double rate_by_count_of_pyramiding() // doubleでいいのか？
{
  double rate;
  switch (pyramidingCount)
  {
    case 0:
      rate = 1.0;
      break;
    case 1:
      rate = 0.85;
      break;
    case 2:
      rate = 0.7;
      break;
    case 3:
      rate = 0.55;
      break;
    case 4:
      rate = 0.4;
      break;
    default:
      rate = 0.25;
      break;
  }

  return rate;
}

// ==============================================================================================
// ==============================================================================================
