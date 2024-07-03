//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

// ロジック：
// 戻り高値導出：
  // 過去に1個ずつ遡っていって、
  // 高値が更新されなくなったら
  // その手前の足の高値が戻り高値。
// 押し安値導出：
  // 過去に1個ずつ遡っていって、
  // 安値が更新されなくなったら
  // その手前の足の安値が押し安値。

// レンジ相場かトレンド継続か：
  // どちらかの条件が満たされていない場合(はらみ足・包み足)に一旦レンジ相場に突入という判断
  // 抱き足：その足の高値安値がレンジの壁になる

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
// 市場閉鎖でSendOrderがエラー発生した場合true
// cancel_opposite_orderでのみ発生している前提のロジックとなっている。
bool isRetcodeMarketClosed;
// int fillType;

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
  isRetcodeMarketClosed = false;
  // fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
  return(INIT_SUCCEEDED);
}


// リファクタリング：グローバル変数の更新はOnTick内のみとするべき。
void OnTick()
{
  if(!isRetcodeMarketClosed){

    // トレンドブレイク中は例外。方向感なくなったときを監視するため
      // ↑ 少なくとも抱き足が確定した瞬間に決済する場合の話
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0); // 現在のバーのオープン時間を取得
    if (currentBarTime == lastBarTime) return; // 足が確定するまではリターン
    lastBarTime = currentBarTime; // 最後のバー時間を更新

  } else {
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime) {
      lastBarTime = currentBarTime;
    }
  }

  ZeroMemory(request);
  ZeroMemory(result);

  if(isInRange){
    // レンジブレイクしていなければ終了

    // retcode 10018(市場閉鎖)フラグがtrueの場合、is_range_brokenチェックをスキップ
    if (!isRetcodeMarketClosed && !is_range_broken()) return;
    isRetcodeMarketClosed = false;

    if(currentDirectionOfBreakout != "both"){
      // 残留している逆指値注文をキャンセル
      // 市場閉鎖エラーが発生した場合、isRetcodeMarketClosedをtrueにする
      cancel_opposite_order();
      if (isRetcodeMarketClosed) return;

      // 前回のブレイク方向とは逆側にブレイクした場合
      if(previousDirectionOfBreakout != "both" && previousDirectionOfBreakout != currentDirectionOfBreakout) {
        close_opposite_positions();
        // pyramidingCount = 0;
      } else {
        // 前回が両方へのブレイクだった or 同方向にブレイクした場合
        // pyramidingCount += 1;
      }

      // 転換点を導出し、grobal変数に格納
      find_and_save_turning_point();
      // ⑦：全てのポジションの損切り注文を更新する
      update_all_stop_loss();
      // レンジブレイクしたためレンジ内ではない
      isInRange = false;

    } else {
      // current~~がbothだった場合

      // ポジション全決済の処理
      close_all_positions();
      // if (isRetcodeMarketClosed) return;
      // pyramidingCount = 0;
      // レンジブレイクした足自体が新しいレンジとなる
      isInRange = true;
    }

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
      // ↓ここで押し安値・戻り高値に代入してはいけない！
    if(!isRetcodeMarketClosed && !is_range_confirmed()) return;
    isRetcodeMarketClosed = false;

    // 逆指値注文をレンジの上下にいれる
    // 市場閉鎖エラーが発生した場合、isRetcodeMarketClosedをtrueにする
    send_order_both_stop_buy_and_stop_sell();
    if (isRetcodeMarketClosed) return;

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
  double latest_bar_high = iHigh(Symbol(),Period(), 1);
  double latest_bar_low = iLow(Symbol(),Period(), 1);
  bool is_updated = false;

  if(latest_bar_high > highOfRange && latest_bar_low < lowOfRange){
    // レンジを上下どちらにも更新した場合
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "both";
    comparativeHigh = latest_bar_high;
    comparativeLow = latest_bar_low;
    // この足がレンジになる
    highOfRange = latest_bar_high;
    lowOfRange = latest_bar_low;
    Print("★レンジをどちらにも抜けた");
    Print("★レンジ上限： ", highOfRange);
    Print("★レンジ下限： ", lowOfRange);
  }

  if(is_updated == false && latest_bar_high > highOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "above";
    comparativeHigh = latest_bar_high;
    comparativeLow = latest_bar_low;
  }

  if(is_updated == false && latest_bar_low < lowOfRange){
    is_updated = true;
    previousDirectionOfBreakout = currentDirectionOfBreakout;
    currentDirectionOfBreakout = "below";
    comparativeHigh = latest_bar_high;
    comparativeLow = latest_bar_low;
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
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      is_confirmed = false;
    } else {
      // 高値が更新されなかった場合

      if (latest_bar_low < comparativeLow) {
        // 安値更新
        highOfRange = comparativeHigh;
        is_confirmed = true;
        Print("★レンジ確定");
        Print("レンジ上限： ", highOfRange);
        Print("レンジ下限（既出）： ", lowOfRange);
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "below"){
    // 下抜け中の場合

    if(latest_bar_low < comparativeLow){
      // 安値更新
      comparativeHigh = latest_bar_high;
      comparativeLow = latest_bar_low;
      is_confirmed = false;
    } else {
      // 安値が更新されなかった場合

      if (latest_bar_high > comparativeHigh) {
        // 高値更新
        lowOfRange = comparativeLow;
        is_confirmed = true;
        Print("★レンジ確定");
        Print("レンジ下限： ", lowOfRange);
        Print("レンジ上限（既出）： ", highOfRange);
      } else {
        // ハラミ足
        is_confirmed = false;
      }
    }
  } else if(currentDirectionOfBreakout == "both"){
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！is_range_confirmed: Logic's fucked up!!!");
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
    Print("★レンジを上に抜けた");
    Print("★レンジ下限： ", lowOfRange);
  } else if(currentDirectionOfBreakout == "below") {
    highOfRange = find_last_high();
    Print("★レンジを下に抜けた");
    Print("★レンジ上限： ", highOfRange);
  } else if(currentDirectionOfBreakout == "both") {
    // current~~がbothのとき、この関数は実行されないはず
    Print("！！！find_and_save_turning_point: Logic's fucked up!!!");
  }
}

// TODO: 色々な考え方がある。何を基準に高値を導出するか？
  // 今回は「買い手と売り手の均衡点」という視点で導出
  // 下がり続けている中で、最後に高値が上がったところが高値の限界点であるとする
double find_last_high()
{
  double last_high;
  // ↓レンジブレイクした足
  double high = iHigh(Symbol(),Period(), 1);
  double low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_high > high){
      // 高値更新
      high = previous_bar_high;
      low = previous_bar_low;
      is_found = false;
    } else {
      // 高値が更新されなかった場合

      if (previous_bar_low < low) {
        // 安値更新
        last_high = high;
        is_found = true;
      } else {
        // はらみ足

        // 抱き足の安値を直近安値とする
        lowOfRange = low;
        is_found = true;
      }
    }
  }

  return last_high;
}

double find_last_low()
{
  double last_low;
  // ↓レンジブレイクした足
  double high = iHigh(Symbol(),Period(), 1);
  double low = iLow(Symbol(),Period(), 1);
  bool is_found = false;
  double previous_bar_high;
  double previous_bar_low;

  for(int i = 2; !is_found; i++){
    previous_bar_high = iHigh(Symbol(),Period(), i);
    previous_bar_low = iLow(Symbol(),Period(), i);

    if(previous_bar_low < low){
      // 安値更新
      high = previous_bar_high;
      low = previous_bar_low;
      is_found = false;
    } else {
      // 安値が更新されなかった場合

      if (previous_bar_high > high) {
        // 高値更新
        last_low = low;
        is_found = true;
      } else {
        // はらみ足

        // 抱き足の高値を直近高値とする
        highOfRange = high;
        is_found = true;
      }
    }
  }

  return last_low;
}


// ==============================================================================================
// ↓逆指値注文 =================================================================================

// TODO: fix bug about return code 10015 :
  // TRADE_RETCODE_INVALID_PRICE (リクエスト内の無効な価格。)
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
  request.deviation = 10;
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
    // result.retcodeが10018のとき、再試行したいため
    if(result.retcode == 10018) isRetcodeMarketClosed = true;
  }
  // print_information_of_send_error("buy_stop");

  // sell_stop //--- 操作パラメータの設定
  ZeroMemory(result); // requestは初期化せず使い回す
  request.type = ORDER_TYPE_SELL_STOP;
  price = lowOfRange - point;
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  sl = highOfRange + point;
  request.sl = NormalizeDouble(sl, digits); // 正規化された損切り価格
  if(!OrderSend(request,result)){
    print_error_of_send_order("sell_stop");
    // result.retcodeが10018のとき、再試行したいため
    if(result.retcode == 10018) isRetcodeMarketClosed = true;
  }
}

// ==============================================================================================
// ↓注文・ポジションの更新/キャンセル/決済 =====================================================

// TODO: fix stop level
 // 10016 TRADE_RETCODE_INVALID_STOPS (リクエスト内の無効なストップ。)
 // →更新前のslとrequest.slが同じ値になっている（←これ目視で確認！！）
void update_all_stop_loss()
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
    } else if(currentDirectionOfBreakout == "both")  {
      // current~~がbothのときだと考えられるが、この関数は実行されないはず

      // レンジをどちらにも抜けたらミスマッチする
      Print("★update_all_stop_loss: Logic's fucked up!!! ");
      Print("type(0=buy, 1=sell): ", type);
      Print("currentDirection: ", currentDirectionOfBreakout);
    }

    //--- リクエストの送信
    if(!OrderSend(request,result)){
      print_error_of_send_order("update_all_stop_loss");
      Print("request.sl: ", request.sl);
      Print("type(0==buy, 1==sell): ", type);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      Print("current ask price: ", ask);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Print("current bid price: ", bid);
    }
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
      // result.retcodeが10018のとき、再試行したいため
      if(result.retcode == 10018) isRetcodeMarketClosed = true;
    }
  }

  // magic_number（適応されているペア）内に逆指値注文は１つだけのはず
    // 片方はポジションになったため
  if(same_magic_count > 1){
    Print("★cancel_opposite_order: same_magic_count is: ", same_magic_count);
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
  } else if(previousDirectionOfBreakout == "both") {
    // previous~~がbothのときはこの関数は実行されないはず
    Print("★close_opposite_positions: Logic's fucked up!!! ");
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
    request.deviation = 10; // 最大許容偏差＝スリッページ（値はポイント）
    request.magic = expertMagic;
    // int fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    request.type_filling = 1;
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
      if(result.retcode == 10030){
        Print("request.type_filling: ", request.type_filling);
      }
    }
    // fillされたときに、残りのポジションを再度closeする。（retcodeでfillポリシーが適用されたか確認する？）
  }
}

void close_all_positions()
{
  int total = PositionsTotal();
  for(int i = total - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    ulong magic = PositionGetInteger(POSITION_MAGIC);
    if(magic != expertMagic) continue; // MagicNumberが一致していない場合スキップ

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    string position_symbol = PositionGetString(POSITION_SYMBOL);
    double volume = PositionGetDouble(POSITION_VOLUME);
    ZeroMemory(request);
    ZeroMemory(result);
    request.action = TRADE_ACTION_DEAL;
    request.position = position_ticket;
    request.symbol = position_symbol;
    request.volume = volume;
    request.deviation = 10; // 最大許容偏差＝スリッページ（値はポイント）
    request.magic = expertMagic;
    // int fillType = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    request.type_filling = 1;
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
      if(result.retcode == 10030){
        Print("request.type_filling: ", request.type_filling);
      }
    }
    // fillされたときに、残りのポジションを再度closeする。（retcodeでfillポリシーが適用されたか確認する？）
  }
}

// ==============================================================================================
// ↓Print共通化 ================================================================================

void print_error_of_send_order(string function_name)
{
  // リクエストの送信に失敗した場合、エラーコードを出力
  PrintFormat("OrderSend(%s) Error: %d", function_name, GetLastError());
  PrintFormat("OrderSend(%s): retcode=%u  deal=%I64u  order=%I64u", function_name, result.retcode, result.deal, result.order);
  print_retcode_message_converted_to_jp(result.retcode);
  ResetLastError(); // GetLastError()で_LastErrorの値が変更されているためリセット
}

void print_retcode_message_converted_to_jp(uint retcode)
{
  switch(retcode) {
    case 10004:
      Print("リクオート。");
      break;
    case 10006:
      Print("リクエストの拒否。");
      break;
    case 10007:
      Print("トレーダーによるリクエストのキャンセル。");
      break;
    case 10008:
      Print("注文が出されました。");
      break;
    case 10009:
      Print("リクエスト完了。");
      break;
    case 10010:
      Print("リクエストが一部のみ完了。");
      break;
    case 10011:
      Print("リクエスト処理エラー。");
      break;
    case 10012:
      Print("リクエストが時間切れでキャンセル。");
      break;
    case 10013:
      Print("無効なリクエスト。");
      break;
    case 10014:
      Print("リクエスト内の無効なボリューム。");
      break;
    case 10015:
      Print("リクエスト内の無効な価格。");
      break;
    case 10016:
      Print("リクエスト内の無効なストップ。");
      break;
    case 10017:
      Print("取引が無効化されています。");
      break;
    case 10018:
      Print("市場が閉鎖中。");
      break;
    case 10019:
      Print("リクエストを完了するのに資金が不充分。");
      break;
    case 10020:
      Print("価格変更。");
      break;
    case 10021:
      Print("リクエスト処理に必要な相場が不在。");
      break;
    case 10022:
      Print("リクエスト内の無効な注文有効期限。");
      break;
    case 10023:
      Print("注文状態の変化。");
      break;
    case 10024:
      Print("頻繁過ぎるリクエスト。");
      break;
    case 10025:
      Print("リクエストに変更なし。");
      break;
    case 10026:
      Print("サーバが自動取引を無効化。");
      break;
    case 10027:
      Print("クライアント端末が自動取引を無効化。");
      break;
    case 10028:
      Print("リクエストが処理のためにロック中。");
      break;
    case 10029:
      Print("注文やポジションが凍結。");
      break;
    case 10030:
      Print("無効な注文充填タイプ。");
      break;
    case 10031:
      Print("取引サーバに未接続。");
      break;
    case 10032:
      Print("操作は、ライブ口座のみで許可。");
      break;
    case 10033:
      Print("未決注文の数が上限に達しました。");
      break;
    case 10034:
      Print("シンボルの注文やポジションのボリュームが限界に達しました。");
      break;
    case 10035:
      Print("不正または禁止された注文の種類。");
      break;
    case 10036:
      Print("指定されたPOSITION_IDENTIFIER を持つポジションがすでに閉鎖。");
      break;
    case 10038:
      Print("決済ボリュームが現在のポジションのボリュームを超過。");
      break;
    case 10039:
      Print("指定されたポジションの決済注文が既存。これは、ヘッジシステムでの作業中に発生する可能性があります。");
      break;
    case 10040:
      Print("アカウントに同時に存在するポジションの数は、サーバー設定によって制限されます。 限度に達すると、サーバーは出された注文を処理するときにTRADE_RETCODE_LIMIT_POSITIONSエラーを返します。 これは、ポジション会計タイプによって異なる動作につながります。");
      break;
    case 10041:
      Print("未決注文アクティベーションリクエストは却下され、注文はキャンセルされます。");
      break;
    case 10042:
      Print("銘柄に\"Only long positions are allowed（買いポジションのみ）\" (POSITION_TYPE_BUY)のルールが設定されているため、リクエストは却下されます。");
      break;
    case 10043:
      Print("銘柄に\"Only short positions are allowed（売りポジションのみ）\" (POSITION_TYPE_SELL)のルールが設定されているため、リクエストは却下されます。");
      break;
    case 10044:
      Print("銘柄に\"Only position closing is allowed（ポジション決済のみ）\"のルールが設定されているため、リクエストは却下されます。");
      break;
    case 10045:
      Print("取引口座に\"Position closing is allowed only by FIFO rule（FIFOによるポジション決済のみ）\"(ACCOUNT_FIFO_CLOSE=true)のフラグが設定されているため、リクエストは却下されます。");
      break;
    case 10046:
      Print("口座で「単一の銘柄の反対のポジションは無効にする」ルールが設定されているため、リクエストが拒否されます。");
      break;
    default:
      Print("未定義のエラーコードです。");
      break;
  }
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
