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
MqlTradeRequest request;
MqlTradeResult result;

int OnInit()
{
  Print("start ea (OnInit)");
  highOfRange = high;
  lowOfRange = low;
  currentDirectionOfBreakout = current_direction_of_breakout;
  previousDirectionOfBreakout = previous_direction_of_breakout;
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
      // 今格納されている値がそのまま、押し目安値or戻り高値になるためロジック不要
    } else {
      // 上抜けの場合：押し目安値、 下抜けの場合：戻り高値 を導出し、grobal変数に格納
      find_and_save_turning_point();
      // ⑦：全てのポジションの損切り注文を更新する
      update_all_stop_loss();
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

// ---------------------------------------------------------

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
    // 押し安値or戻り安値
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
  request.volume = 0.1; // TODO: ロスカットしたときの損失が証拠金の1%になるようにする
  request.deviation = 5;
  request.magic = expertMagic;
  double price;
  double sl;
  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  int digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); // 小数点以下の桁数（精度）

  // buy_stop //--- 操作パラメータの設定
  request.type = ORDER_TYPE_BUY_STOP;
  price = highOfRange + point;
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  sl = lowOfRange - point;
  request.sl = NormalizeDouble(sl, digits); // ★チェック
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

void print_error_of_send_order(string function_name)
{
  PrintFormat("！！！OrderSend(%s) Error: %d", function_name, GetLastError()); // リクエストの送信に失敗した場合、エラーコードを出力
  ResetLastError(); // GetLastError()で_LastErrorの値が変更されているためリセット
}

void print_information_of_send_error(string function_name)
{
  PrintFormat("OrderSend(%s): retcode=%u  deal=%I64u  order=%I64u", function_name, result.retcode, result.deal, result.order);
}

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


ENUM_ORDER_TYPE_FILLING FillPolicy()
{
  long fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  if(fillType==SYMBOL_FILLING_IOC)return ORDER_FILLING_IOC;
  else if(fillType==SYMBOL_FILLING_FOK)return ORDER_FILLING_FOK;
  else return ORDER_FILLING_RETURN;
}

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
