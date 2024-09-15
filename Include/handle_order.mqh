// レンジの上下に逆指値注文を置く
void send_order_both_stop_buy_and_stop_sell()
{
  ZeroMemory(request);
  ZeroMemory(result);
  // レンジの上限・下限を少し超えた位置に逆指値注文を置く
    // 注文はそれぞれレンジの反対側で損切りするように設定する

  request.action = TRADE_ACTION_PENDING;
  request.symbol = Symbol();
  request.deviation = 10;
  request.magic = expertMagic;
  double price;
  double sl;
  double point = Point();
  int digits = Digits();

  // buy_stop //--- 操作パラメータの設定
  request.type = ORDER_TYPE_BUY_STOP;
  price = highOfRange + point;
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  sl = lowOfRange - point;
  request.sl = NormalizeDouble(sl, digits); // 正規化された損切り価格
  request.volume = volume_with_risk_manegemant();
  if(!OrderSend(request,result)){
    print_error_of_send_order("buy_stop");
    // （市場閉鎖エラーの場合、再試行したいため
    if(result.retcode == 10018) isMarketClosed = true;
  }

  // sell_stop //--- 操作パラメータの設定
  ZeroMemory(result); // requestは初期化せず使い回す
  request.type = ORDER_TYPE_SELL_STOP;
  price = lowOfRange - point;
  request.price = NormalizeDouble(price, digits); // 正規化された発注価格
  sl = highOfRange + point;
  request.sl = NormalizeDouble(sl, digits); // 正規化された損切り価格
  if(!OrderSend(request,result)){
    print_error_of_send_order("sell_stop");
    // 市場閉鎖エラーの場合、再試行したいため
    if(result.retcode == 10018) isMarketClosed = true;
  }
}

// ==================================================
// 損切りの更新をする

// TODO: USDJPY 2022/3/16 リクエスト内の無効なストップ
    // ex) 2021/11/26 is_rage_confirm中に逆側にレンジブレイクしてしまうパターン
      // →
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

//=================================================
// レンジブレイクの逆の注文をキャンセルする
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
      if(result.retcode == 10018) isMarketClosed = true;
    }
  }

  // magic_number（適応されているペア）内に逆指値注文は１つだけのはず
    // 片方はポジションになったため
  if(same_magic_count > 1){
    Print("★cancel_opposite_order: same_magic_count is: ", same_magic_count);
  }
}

// ==============================================
// レンジブレイクの逆のポジションを決済する
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
    // TODO: type_fillingの値を動的に変える。
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

// =================================================
// すべてのポジションを決済する
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
      // result.retcodeが10018のとき、再試行したいため
      if(result.retcode == 10018) isMarketClosed = true;
      if(result.retcode == 10030){
        Print("request.type_filling: ", request.type_filling);
      }
    }
    // fillされたときに、残りのポジションを再度closeする。（retcodeでfillポリシーが適用されたか確認する？）
  }
}
