//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

// 方向感なくなったときに見

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
double comparativeHigh; // ブレイク中の比較対象の足の高値
double comparativeLow; // ブレイク中の比較対象の足の安値
datetime lastBarTime; // 最後に確認したバーの時間を格納する変数
MqlTradeRequest request;
MqlTradeResult result;

int OnInit()
{
  highOfRange = high;
  lowOfRange = low;
  currentDirectionOfBreakout = current_direction_of_breakout;
  previousDirectionOfBreakout = previous_direction_of_breakout;
  pyramidingCount = 0;
  send_order_both_stop_buy_and_stop_sell();
  isInRange = true;
  comparativeHigh = 0.0;
  comparativeLow = 0.0;
  lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
  return(INIT_SUCCEEDED);
}


// リファクタリング：グローバル変数の更新はOnTick内のみとするべき。
void OnTick()
{
  // トレンドブレイク中は例外。方向感なくなったときを監視するため
    // ↑ 少なくとも抱き足が確定した瞬間に決済する場合の話
  datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0); // 現在のバーのオープン時間を取得
  if (currentBarTime == lastBarTime) return; // 足が確定するまではリターン
  lastBarTime = currentBarTime; // 最後のバー時間を更新

  ZeroMemory(request);
  ZeroMemory(result);

  if(isInRange){
    // レンジブレイクしていなければ終了
    // リファクタリング
      // previousDirectionOfBreakout
      // currentDirectionOfBreakout
      // comparativeHigh
      // comparativeLow
    if(!is_range_broken()) return;
    // 残留している逆指値注文をキャンセル
    cancel_opposite_order();
    // 前回のブレイク方向とは逆側にブレイクした場合
    if(previousDirectionOfBreakout != currentDirectionOfBreakout) {
      close_opposite_positions();
      // TODO:
      // ★押し目安値・戻り高値：レンジ内における直前の安値・高値（レンジ内で一番高い・低いは関係ない。レンジ内の最後の均衡点が押し目・戻りになるというロジック）
      find_and_save_turning_point();
      pyramidingCount = 0;
    } else {
      // 上抜けの場合：押し目安値、 下抜けの場合：戻り高値 を導出し、grobal変数に格納
      find_and_save_turning_point();
      // ⑦：全てのポジションの損切り注文を更新する
      update_all_stop_loss();
      pyramidingCount += 1;
    }

    isInRange = false; // レンジブレイクしたためレンジ内ではない
    return;
  }

  if(!isInRange){
    // ④：天井or底が確定するのを待つ(更新が終わるのを待つ)
      // 更新されていたら（＝レンジが確定していないなら）：終了
      // 更新されなかったら（レンジが確定したなら）：再度レンジ導出(B)

    // リファクタリング
      // highOfRange
      // lowOfRange
      // comparativeHigh
      // comparativeLow
    if(!is_range_confirmed()) return;

    // ⑥：新規の逆指値注文をレンジBの上下に入れる。
      // 位置や損切りは②と同じ
    send_order_both_stop_buy_and_stop_sell();
    isInRange = true; // レンジが確定したためレンジ内である
    return;
  }
}

// ==============================================================================================
// ==============================================================================================


// ↓レンジ確認 =================================================================================


// 値が格納されるglobal変数
    // previousDirectionOfBreakout
    // currentDirectionOfBreakout
    // comparativeHigh
    // comparativeLow
bool is_range_broken()
{
  // 一旦、レンジの幅を超えてたらレンジブレイク確定というロジックにする。
    // TODO: スリッページのせいで注文が執行されない問題が発生したら
    // →注文が執行されていたらレンジブレイク確定というロジックに変更する。

  // ↓現在進行系の足の一個前ということ→確定済みの足（最新）
  double previous_high = iHigh(Symbol(),Period(), 1);
  double previous_low = iLow(Symbol(),Period(), 1);
  bool is_updated;

  if(previous_high > highOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "above";
    comparativeHigh = previous_high;
    comparativeLow = previous_low;
  } else {
    is_updated = false;
  }

  // ↓レンジの上下を同時に更新するのは考えにくいため
  if(is_updated == false ){
    if(previous_low < lowOfRange){
      is_updated = true;
      previousDirectionOfBreakout = currentDirectionOfBreakout;
      currentDirectionOfBreakout = "below";
      comparativeHigh = previous_high;
      comparativeLow = previous_low;
    } else {
      is_updated = false;
    }
  }

  return is_updated;
}


// 値が格納されるglobal変数
    // 天井 | 底
    // highOfRange | lowOfRange
    // comparativeHigh
    // comparativeLow

// TODO: 条件の比較をboolean関数にする
bool is_range_confirmed()
{
  double previous_high;
  double previous_low;
  bool is_confirmed;
  // 最新の確定した足
  previous_high = iHigh(Symbol(),Period(), 1);
  previous_low = iLow(Symbol(),Period(), 1);

  if(currentDirectionOfBreakout == "above"){
    // 上抜け中の場合

    if(previous_high <= comparativeHigh){
      // 高値が更新されなかった場合

      // レンジ確定
      highOfRange = comparativeHigh;
      is_confirmed = true;
      if (previous_low >= comparativeLow) {
        // ハラミ足だった場合

        // レンジ確定(底＝ハラミ足の直前足の安値)
        lowOfRange = comparativeLow;
      }
    } else {
      // 高値を更新した場合

      if (previous_low < comparativeLow) {
        // 抱き足だった場合

        // レンジ確定(天井・底＝抱き足の高値・安値)
        highOfRange = previous_high;
        lowOfRange = previous_low;
        is_confirmed = true;
      } else {
        // トレンド維持

        comparativeHigh = previous_high;
        comparativeLow = previous_low;
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合

    if(previous_low >= comparativeLow){
      // 安値が更新されなかった場合

      // レンジ確定
        lowOfRange = comparativeLow;
        is_confirmed = true;
      if (previous_high <= comparativeHigh) {
        // ハラミ足だった場合

        // レンジ確定(天井＝ハラミ足の直前足の高値)
        highOfRange = comparativeHigh
      }
    } else {
      // 安値を更新した場合

      if (previous_high > comparativeHigh) {
        // 抱き足だった場合

        // レンジ確定(天井・底＝抱き足の高値・安値)
        highOfRange = previous_high;
        lowOfRange = previous_low;
        is_confirmed = true;
      } else {
        // トレンド維持

        comparativeHigh = previous_high;
        comparativeLow = previous_low;
        is_confirmed = false;
      }
    }
  } else {
    // Error
  }

  return is_confirmed;
}

// 値が格納されるglobal変数
    // 押し安値 | 戻り高値
    // lowOfRange | highOfRange
// TODO:
// ★押し目安値・戻り高値：レンジ内における直前の安値・高値（レンジ内で一番高い・低いは関係ない。レンジ内の最後の均衡点が押し目・戻りになるというロジック）
void find_and_save_turning_point()
{
  if(currentDirectionOfBreakout == "above"){
    lowOfRange = find_last_low();
  } else if(currentDirectionOfBreakout == "below") {
    highOfRange = find_last_high();
  } else {
  }
}

// TODO: 色々な考え方がある。何を基準に高値を導出するか？
  // 今回は「買い手と売り手の均衡点」という視点で導出
  // 下がり続けている中で、最後に高値が上がったところが高値の限界点であるとする
double find_last_high()
{
  double last_high;
  // ↓レンジブレイクした足の高値
  double previous_bar_high = iHigh(Symbol(),Period(), 1);
  bool is_not_found = true;
  double high;
  for(int i = 2; is_not_found; i++){
    high = iHigh(Symbol(),Period(), i);
    if(high > previous_bar_high){
      previous_bar_high = high
    } else {
      last_high = previous_bar_high;
      is_not_found = false;
    }
  }

  return last_high;
}

double find_last_low()
{
  double last_low;
  // ↓レンジブレイクした足の安値
  double previous_bar_low = iLow(Symbol(),Period(), 1);
  bool is_not_found = true;
  double low;
  for(int i = 2; is_not_found; i++){
    low = iLow(Symbol(),Period(), i);
    if(low < previous_bar_low){
      previous_bar_low = low
    } else {
      last_low = previous_bar_low;
      is_not_found = false;
    }
  }

  return last_low;
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
  double point = Point();
  int digits = Digits(); // 小数点以下の桁数（精度）

  // buy_stop //--- 操作パラメータの設定
  request.type = ORDER_TYPE_BUY_STOP;
  price = highOfRange + point;
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  sl = lowOfRange - point;
  request.sl = NormalizeDouble(sl, digits); // 正規化された損切り価格
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
  request.sl = NormalizeDouble(sl, digits); // 正規化された損切り価格
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
    // slを更新する→上抜けの場合：押し目安値、 下抜けの場合：戻り高値
    // →currentDirectionOfBreakoutの値に合わせてlow_・high_のどちらの値をslにするかを変える

  int total = PositionsTotal();
  for(int i = total - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    ulong magic = PositionGetInteger(POSITION_MAGIC); // ポジションのMagicNumber
    if(magic != expertMagic) continue; // MagicNumberが一致していない場合スキップ

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    double sl;
    double point = SymbolInfoDouble(position_symbol, SYMBOL_POINT); // positionのsymbolにしてないけど、magicチェックしてるし平気でしょ
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS); // 小数点以下の桁数
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // ポジションタイプ

    ZeroMemory(request);
    ZeroMemory(result);
    request.action = TRADE_ACTION_SLTP;
    request.position = position_ticket;
    request.symbol = position_symbol;
    request.magic = magic;

    if(type == POSITION_TYPE_BUY && currentDirectionOfBreakout == "above") // 一致するはず
    {
      sl = lowOfRange - point;
      request.sl = NormalizeDouble(sl, digits);
    } else if(type == POSITION_TYPE_SELL && currentDirectionOfBreakout == "below")  {
      sl = highOfRange + point;
      request.sl = NormalizeDouble(sl, digits);
    } else {
    }

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
  }
}

void close_opposite_positions()
{
  ENUM_POSITION_TYPE type_of_position_closing;
  if(previousDirectionOfBreakout == "above")
  {
    type_of_position_closing = POSITION_TYPE_SELL;
  } else if(previousDirectionOfBreakout == "below")
  {
    type_of_position_closing = POSITION_TYPE_BUY;
  } else {
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
      request.price = SymbolInfoDouble(position_symbol, SYMBOL_BID);
      request.type = ORDER_TYPE_SELL;
    } else {
      request.price = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
      request.type = ORDER_TYPE_BUY;
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
  volume = verify_volume(volume);
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
