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
double comparative_high; // ブレイク中の比較対象の足の高値
double comparative_low; // ブレイク中の比較対象の足の安値
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
  comparative_high = 0.0;
  comparative_low = 0.0;
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

  Print("[OnTick] [global] highOfRange:", highOfRange);
  Print("[OnTick] [global] lowOfRange:", lowOfRange);
  Print("[OnTick] [global] currentDirectionOfBreakout:", currentDirectionOfBreakout);
  Print("[OnTick] [global] previousDirectionOfBreakout:", previousDirectionOfBreakout);
  Print("[OnTick] [global] isInRange:", isInRange);
  Print("[OnTick] pyramidingCount: ", pyramidingCount);
}

// ==============================================================================================
// ==============================================================================================


// ↓レンジ確認 =================================================================================


// 値が格納されるglobal変数
    // previousDirectionOfBreakout
    // currentDirectionOfBreakout
    // comparative_high
    // comparative_low
bool is_range_broken()
{
  // 一旦、レンジの幅を超えてたらレンジブレイク確定というロジックにする。
    // TODO: スリッページのせいで注文が執行されない問題が発生したら
    // →注文が執行されていたらレンジブレイク確定というロジックに変更する。

  // ↓現在進行系の足の一個前ということ→確定済みの足（最新）
  double previous_high = iHigh(Symbol(),Period(), 1);
  Print("[is_range_broken] previous_high: ", previous_high);
  double previous_low = iLow(Symbol(),Period(), 1);
  Print("[is_range_broken] previous_low: ", previous_low);
  bool is_updated;

  if(previous_high > highOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    Print("[is_range_broken] previousDirectionOfBreakout <above>: ", previousDirectionOfBreakout);
    currentDirectionOfBreakout = "above";
    Print("[is_range_broken] currentDirectionOfBreakout <above>: ", currentDirectionOfBreakout);
    comparative_high = previous_high;
    Print("[is_range_broken] comparative_high <above>: ", comparative_high);
    comparative_low = previous_low;
    Print("[is_range_broken] comparative_low <above>: ", comparative_low);
  } else {
    is_updated = false;
  }

  // ↓レンジの上下を同時に更新するのは考えにくいため
  if(is_updated == false ){
    if(previous_low < lowOfRange){
      is_updated = true;
      previousDirectionOfBreakout = currentDirectionOfBreakout;
      Print("[is_range_broken] previousDirectionOfBreakout <below>: ", previousDirectionOfBreakout);
      currentDirectionOfBreakout = "below";
      Print("[is_range_broken] currentDirectionOfBreakout <below>: ", currentDirectionOfBreakout);
      comparative_high = previous_high;
      Print("[is_range_broken] comparative_high <below>: ", comparative_high);
      comparative_low = previous_low;
      Print("[is_range_broken] comparative_low <below>: ", comparative_low);
    } else {
      is_updated = false;
    }
  }

  Print("[is_range_broken] is_updated: ", is_updated);
  return is_updated;
}


// 値が格納されるglobal変数
    // 天井or底
bool is_range_confirmed()
{
  double previous_high;
  double previous_low;
  bool is_confirmed;
  // 最新の確定した足
  previous_high = iHigh(Symbol(),Period(), 1);
  previous_low = iLow(Symbol(),Period(), 1);
  Print("[is_range_confirmed] previous_high: ", previous_high);
  Print("[is_range_confirmed] previous_low: ", previous_low);
  Print("[is_range_confirmed] comparative_high: ", comparative_high);
  Print("[is_range_confirmed] comparative_low: ", comparative_low);

  if(currentDirectionOfBreakout == "above"){
    // 上抜け中の場合
    if(previous_high <= comparative_high){
      // 高値が更新されなかった場合

      if (previous_low >= comparative_low) {
        // ハラミ足だった場合
        is_confirmed = false;
      } else {
        // レンジ確定
        Print("[is_range_confirmed] highOfRange <above><before>: ", highOfRange);
        highOfRange = comparative_high;
        Print("[is_range_confirmed] highOfRange <above><after>: ", highOfRange);
        is_confirmed = true;
        comparative_high = 0.0;
        comparative_low = 0.0;
        Print("[is_range_confirmed] comparative_high <above><1>: ", comparative_high);
        Print("[is_range_confirmed] comparative_low <above><1>: ", comparative_low);
      }
    } else {
      // 高値を更新した場合
      comparative_high = previous_high;
      comparative_low = previous_low;
      Print("[is_range_confirmed] comparative_high <above><2>: ", comparative_high);
      Print("[is_range_confirmed] comparative_low <above><2>: ", comparative_low);
      is_confirmed = false;
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合
    if(previous_low >= comparative_low){
      // 安値が更新されなかった場合

      if (previous_high <= comparative_high) {
        // ハラミ足だった場合
        is_confirmed = false;
      } else {
        // レンジ確定
        Print("[is_range_confirmed] lowOfRange <below><before>: ", lowOfRange);
        lowOfRange = comparative_low;
        Print("[is_range_confirmed] lowOfRange <below><after>: ", lowOfRange);
        is_confirmed = true;
        comparative_low = 0.0;
        comparative_high = 0.0;
        Print("[is_range_confirmed] comparative_low <below><1>: ", comparative_low);
        Print("[is_range_confirmed] comparative_high <below><1>: ", comparative_high);
      }
    } else {
      // 安値を更新した場合
      comparative_low = previous_low;
      comparative_high = previous_high;
      Print("[is_range_confirmed] comparative_low <below><2>: ", comparative_low);
      Print("[is_range_confirmed] comparative_high <below><2>: ", comparative_high);
      is_confirmed = false;
    }
  } else {
    Print("ERROR!! [is_range_confirmed] currentDirectionOfBreakout: ", currentDirectionOfBreakout);
  }

  Print("[is_range_confirmed] is_confirmed: ", is_confirmed);
  return is_confirmed;
}

// 値が格納されるglobal変数
    // 押し安値or戻り高値
void find_and_save_turning_point()
{
  // ENHANCE: 前回のpeak・bottomをglobalで扱う
  int index;
  int previous_peak_index;
  int previous_bottom_index;
  if(currentDirectionOfBreakout == "above"){
    previous_peak_index = count_bars_from_previous_peak_or_bottom();
    Print("[find_and_save_turning_point] previous_peak_index: ", previous_peak_index);
    index = iLowest(Symbol(), Period(), MODE_LOW, previous_peak_index, 1);
    Print("[find_and_save_turning_point] index: ", index);
    Print("[find_and_save_turning_point] lowOfRange <1>: ", lowOfRange);
    lowOfRange = iLow(Symbol(),Period(), index + 1);
    Print("[find_and_save_turning_point] lowOfRange <2>: ", lowOfRange);
  } else if(currentDirectionOfBreakout == "below") {
    previous_bottom_index = count_bars_from_previous_peak_or_bottom();
    Print("[find_and_save_turning_point] previous_bottom_index: ", previous_bottom_index);
    index = iHighest(Symbol(), Period(), MODE_HIGH, previous_bottom_index, 1);
    Print("[find_and_save_turning_point] index: ", index);
    Print("[find_and_save_turning_point] highOfRange <1>: ", highOfRange);
    highOfRange = iHigh(Symbol(),Period(), index + 1);
    Print("[find_and_save_turning_point] highOfRange <2>: ", highOfRange);
  } else {
    Print("ERROR!! [find_and_save_turning_point] currentDirectionOfBreakout: ", currentDirectionOfBreakout);
  }
}

int count_bars_from_previous_peak_or_bottom()
{
  // TODO: データ型とかのせいで、小数点の値がズレたりしてるかも
  int index;
  bool is_not_found = true;

  if(currentDirectionOfBreakout == "above"){
    // 天井までの足の数を導き出す
    double high;
    // 直前の確定済み足から始める→ i = 1;
    for(int i = 1; is_not_found; i++)
    {
      high = iHigh(Symbol(),Period(), i);
      if(high == highOfRange){ // TODO: highを正規化とかしてないなら一致しないんじゃね？→無限ループになりそう
        index = i;
        is_not_found = false;
        Print("[count_bars_from_previous_peak_or_bottom] index <1><high>: ", index);
      }
      if (i == 300) {
        Print("INFINITE LOOP!? [count_bars_from_previous_peak_or_bottom] <1><high>");
        break;
      }
    }
    Print("[count_bars_from_previous_peak_or_bottom] high: ", high);
  } else if(currentDirectionOfBreakout == "below") {
    // 底までの足の数を導き出す
    double low;
    // 直前の確定済み足から始める→ i = 1;
    for(int i = 1; is_not_found; i++)
    {
      low = iLow(Symbol(),Period(), i);
      if(low == lowOfRange){ // TODO: lowを正規化とかしてないなら一致しないんじゃね？→無限ループになりそう
        index = i;
        is_not_found = false;
        Print("[count_bars_from_previous_peak_or_bottom] index <2><low>: ", index);
      }
      if (i == 300) {
        Print("INFINITE LOOP!? [count_bars_from_previous_peak_or_bottom] <2><low>");
        break;
      }
    }
    Print("[count_bars_from_previous_peak_or_bottom] low: ", low);
  } else {
    Print("ERROR!! [count_bars_from_previous_peak_or_bottom] currentDirectionOfBreakout: ", currentDirectionOfBreakout);
  }

  // TODO: indexの値がおかしかったらエラー制御
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
  double point = Point();
  Print("[send_order_both_stop_buy_and_stop_sell] point: ", point);
  int digits = Digits(); // 小数点以下の桁数（精度）
  Print("[send_order_both_stop_buy_and_stop_sell] digits: ", digits);

  // buy_stop //--- 操作パラメータの設定
  request.type = ORDER_TYPE_BUY_STOP;
  price = highOfRange + point;
  Print("[send_order_both_stop_buy_and_stop_sell] price <1> <buy_stop>: ", price);
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  Print("[send_order_both_stop_buy_and_stop_sell] request.price <1> <buy_stop>: ", request.price);
  sl = lowOfRange - point;
  Print("[send_order_both_stop_buy_and_stop_sell] sl <1> <buy_stop>: ", sl);
  request.sl = NormalizeDouble(sl, digits); // 正規化された損切り価格
  Print("[send_order_both_stop_buy_and_stop_sell] request.sl <1> <buy_stop>: ", request.sl);
  request.volume = volume_with_risk_manegemant();
  Print("[send_order_both_stop_buy_and_stop_sell] request.volume <1> <buy_stop>: ", request.volume);
  if(!OrderSend(request,result)){
    print_error_of_send_order("buy_stop");
  }
  print_information_of_send_error("buy_stop");

  // sell_stop //--- 操作パラメータの設定
  ZeroMemory(result); // requestは初期化せず使い回す
  request.type = ORDER_TYPE_SELL_STOP;
  price = lowOfRange - point;
  Print("[send_order_both_stop_buy_and_stop_sell] price <2> <sell_stop>: ", price);
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  Print("[send_order_both_stop_buy_and_stop_sell] request.price <2> <sell_stop>: ", request.price);
  sl = highOfRange + point;
  Print("[send_order_both_stop_buy_and_stop_sell] sl <2> <sell_stop>: ", sl);
  request.sl = NormalizeDouble(sl, digits); // 正規化された損切り価格
  Print("[send_order_both_stop_buy_and_stop_sell] request.sl <2> <sell_stop>: ", request.sl);
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

  int total = PositionsTotal();
  Print("[update_all_stop_loss] total: ", total);
  for(int i = total - 1; i >= 0; i--)
  {
    Print("[update_all_stop_loss] (loop index) i: ", i);
    ulong position_ticket = PositionGetTicket(i);
    Print("[update_all_stop_loss] position_ticket: ", position_ticket);
    ulong magic = PositionGetInteger(POSITION_MAGIC); // ポジションのMagicNumber
    Print("[update_all_stop_loss] magic: ", magic);
    if(magic != expertMagic) continue; // MagicNumberが一致していない場合スキップ

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    Print("[update_all_stop_loss] position_symbol: ", position_symbol);
    double sl;
    double point = SymbolInfoDouble(position_symbol, SYMBOL_POINT); // positionのsymbolにしてないけど、magicチェックしてるし平気でしょ
    Print("[update_all_stop_loss] point: ", point);
    int digits = (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS); // 小数点以下の桁数
    Print("[update_all_stop_loss] digits: ", digits);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // ポジションタイプ
    Print("[update_all_stop_loss] type: ", type);

    ZeroMemory(request);
    ZeroMemory(result);
    //--- 操作パラメータの設定
    request.action = TRADE_ACTION_SLTP;
    request.position = position_ticket;
    request.symbol = position_symbol;
    request.magic = magic;
    // request.tp = tp; // これはいらないはずだが、リクエストになければどうなるのか。。

    if(type == POSITION_TYPE_BUY && currentDirectionOfBreakout == "above") // 一致するはず
    {
      sl = lowOfRange - point;
      Print("[update_all_stop_loss] sl <1> <buy>: ", sl);
      request.sl = NormalizeDouble(sl, digits);
      Print("[update_all_stop_loss] request.sl <1> <buy>: ", request.sl);
    } else if(type == POSITION_TYPE_SELL && currentDirectionOfBreakout == "below")  {
      sl = highOfRange + point;
      Print("[update_all_stop_loss] sl <2> <sell>: ", sl);
      request.sl = NormalizeDouble(sl, digits);
      Print("[update_all_stop_loss] request.sl <2> <sell>: ", request.sl);
    } else {
      Print("ERROR!! [update_all_stop_loss] : ポジションのタイプとレンジブレイク方向が一致していない");
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
  Print("[cancel_opposite_order] total: ", total);
  for(int i = total - 1; i >= 0; i--)
  {
    Print("[cancel_opposite_order] (loop index) i: ", i);
    ulong order_ticket = OrderGetTicket(i);
    Print("[cancel_opposite_order] order_ticket: ", order_ticket);
    ulong magic = OrderGetInteger(ORDER_MAGIC);
    Print("[cancel_opposite_order] magic: ", magic);
    if(magic!=expertMagic) continue; // MagicNumberが一致していない場合スキップ

    same_magic_count++;
    ZeroMemory(request);
    ZeroMemory(result);
    request.action = TRADE_ACTION_REMOVE;
    request.order = order_ticket;
    Print("[cancel_opposite_order] request.order: ", request.order);
    // 残留した未決注文をキャンセル
    if(!OrderSend(request,result)){
      print_error_of_send_order("cancel_opposite_order");
    }
    print_information_of_send_error("cancel_opposite_order");
  }

  // magic_number（適応されているペア）内に逆指値注文は１つだけのはず
    // 片方はポジションになったため
  if(same_magic_count > 1){
    Print("Error!! [cancel_opposite_order]: レンジブレイクしたのに未決注文が2つ以上存在している");
    Print("[cancel_opposite_order] 未決注文数: ", same_magic_count);
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
    Print("ERROR!! [close_opposite_positions] previousDirectionOfBreakout: ", previousDirectionOfBreakout);
  }
  Print("[close_opposite_positions] type_of_position_closing: ", type_of_position_closing);

  int total = PositionsTotal();
  Print("[close_opposite_positions] total: ", total);
  for(int i = total - 1; i >= 0; i--)
  {
    Print("[close_opposite_positions] (loop index) i: ", i);
    ulong position_ticket = PositionGetTicket(i);
    Print("[close_opposite_positions] position_ticket: ", position_ticket);
    ulong magic = PositionGetInteger(POSITION_MAGIC);
    Print("[update_all_stop_loss] magic: ", magic);
    if(magic != expertMagic) continue; // MagicNumberが一致していない場合スキップ

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    Print("[update_all_stop_loss] type: ", type);
    if(type != type_of_position_closing) continue; // type一致しない場合、削除対象のポジションではないためスキップ

    string position_symbol = PositionGetString(POSITION_SYMBOL);
    Print("[close_opposite_positions] position_symbol: ", position_symbol);
    double volume = PositionGetDouble(POSITION_VOLUME);
    Print("[close_opposite_positions] volume: ", volume);
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
      Print("[close_opposite_positions] request.price <1>: ", request.price);
      request.type = ORDER_TYPE_SELL;
    } else {
      request.price = SymbolInfoDouble(position_symbol, SYMBOL_ASK);
      Print("[close_opposite_positions] request.price <2>: ", request.price);
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
  Print("[volume_with_risk_manegemant] digits: ", digits);
  // 証拠金に対する損失額の割合（X %）
  // ピラミッディングの回数でrateを変える
  double rate = rate_by_count_of_pyramiding();
  Print("[volume_with_risk_manegemant] rate: ", rate);
  // 証拠金;
  double margin = AccountInfoDouble(ACCOUNT_BALANCE);
  Print("[volume_with_risk_manegemant] margin: ", margin);
  // 許容損失額
  double loss_amount = margin * (rate / 100);
  Print("[volume_with_risk_manegemant] loss_amount <1>: ", loss_amount);
  loss_amount = NormalizeDouble(loss_amount, digits);
  Print("[volume_with_risk_manegemant] loss_amount <2>: ", loss_amount);

  double price = request.price;
  Print("[volume_with_risk_manegemant] price: ", price);
  double sl = request.sl;
  Print("[volume_with_risk_manegemant] sl: ", sl);
  // 損失幅（値幅） = price - sl => 絶対値
  double loss_extent = MathAbs(price - sl);
  Print("[volume_with_risk_manegemant] loss_extent <1>: ", loss_extent);
  loss_extent = NormalizeDouble(loss_extent, digits);
  Print("[volume_with_risk_manegemant] loss_extent <2>: ", loss_extent);
  // ポジションサイズ
  double position_size = loss_amount / loss_extent;
  Print("[volume_with_risk_manegemant] position_size <1>: ", position_size);

  // 通貨ペアのうちの決済通貨を抽出
  string symbol = Symbol();
  // TODO: 別の関数にしてリファクタ
  string settlement_currency;
  int length = StringLen(symbol);
  Print("[volume_with_risk_manegemant] length: ", length);
  if(length > 3) {
  // if(length == 6) { // こっちのほうが良さそう
    // 最初の3文字を取り除いて残りの文字列を取得
    settlement_currency = StringSubstr(symbol, 3, length - 3);
  } else {
    // 元の文字列が3文字以下の場合は、空の文字列を返す
    settlement_currency = "";
  }
  Print("[volume_with_risk_manegemant] settlement_currency: ", settlement_currency);

  if (settlement_currency != "JPY") {
    // 円を含まない通貨ペアの場合↓
       // 決済通貨の対円レート（右側の通貨）で割る
    string current_with_jpy = settlement_currency;
    Print("[volume_with_risk_manegemant] current_with_jpy <1>: ", current_with_jpy);
    StringAdd(current_with_jpy, "JPY");
    Print("[volume_with_risk_manegemant] current_with_jpy <2>: ", current_with_jpy);

    MqlTick tick;
    double symbol_rate;
    // 最新のティックデータを取得
    if(SymbolInfoTick(current_with_jpy, tick)){
      // ask価格とbid価格の平均を取得して対円レートとして使用
      symbol_rate = (tick.ask + tick.bid) / 2.0;
      Print("[volume_with_risk_manegemant] symbol_rate: ", symbol_rate);
      position_size = position_size / symbol_rate;
      Print("[volume_with_risk_manegemant] position_size <2>: ", position_size);
    }
    else{
      // データ取得に失敗した場合のエラーメッセージ
      Print("[volume_with_risk_manegemant] 対円レートの取得に失敗しました。");
      // TODO: GetLastError();
    }
    // 整数に丸める（ほんとに必要？）
    position_size = MathRound(position_size);
    Print("[volume_with_risk_manegemant] position_size <3>: ", position_size);
  }

  double amount_currency_of_one_lot = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
  Print("[volume_with_risk_manegemant] amount_currency_of_one_lot: ", amount_currency_of_one_lot);
  double volume = position_size / amount_currency_of_one_lot;
  Print("[volume_with_risk_manegemant] volume <1>: ", volume);
  volume = verify_volume(volume);
  Print("[volume_with_risk_manegemant] volume <2>: ", volume);
  return volume;
}

double verify_volume(double volume)
{
  Print("[verify_volume] volume: ", volume);

  double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  Print("[verify_volume] minVolume: ", minVolume);
	double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  Print("[verify_volume] maxVolume: ", maxVolume);
	double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  Print("[verify_volume] stepVolume: ", stepVolume);

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
  Print("[verify_volume] tradeSize <1>: ", tradeSize);

  // 念のため再度ステップ幅に応じて正規化
	if(stepVolume >= 0.1){
    tradeSize = NormalizeDouble(tradeSize, 1);
  } else {
    tradeSize = NormalizeDouble(tradeSize, 2);
  }
  Print("[verify_volume] tradeSize <2>: ", tradeSize);

	return(tradeSize);
}

double rate_by_count_of_pyramiding() // doubleでいいのか？
{
  double rate;
  Print("[verify_volume] pyramidingCount: ", pyramidingCount);
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
