#define EXPERT_MAGIC 100 // エキスパートアドバイザのMagicNumber
//+------------------------------------------------------------------+
//| 全てのポジションを決済                                                  |
//+------------------------------------------------------------------+
void OnStart()
{
//--- 結果とリクエストの宣言
  MqlTradeRequest request;
  MqlTradeResult  result;
  int total=PositionsTotal(); // 保有ポジション数
  Print("決済ポジション数",total);
//--- 全ての保有ポジションの取捨
  for(int i=total-1; i>=0; i--)
    {
    //--- 注文のパラメータ
    ulong  position_ticket=PositionGetTicket(i);                                     // ポジションチケット
    string position_symbol=PositionGetString(POSITION_SYMBOL);                       // シンボル
    int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);             // 小数点以下の桁数
    ulong  magic=PositionGetInteger(POSITION_MAGIC);                                 // ポジションのMagicNumber
    double volume=PositionGetDouble(POSITION_VOLUME);                                 // ポジションボリューム
    ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);   // ポジションタイプ
    //--- ポジション情報の出力
    PrintFormat("#%I64u %s  %s  %.2f  %s [%I64d]",
                position_ticket,
                position_symbol,
              EnumToString(type),
                volume,
              DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits),
                magic);
    //--- MagicNumberが一致している場合
    // if(magic==EXPERT_MAGIC)
    //   {
        //--- リクエストと結果の値のゼロ化
        ZeroMemory(request);
        ZeroMemory(result);
        //--- 操作パラメータの設定
        request.action   =TRADE_ACTION_DEAL;       // 取引操作タイプ
        request.position =position_ticket;         // ポジションチケット
        request.symbol   =position_symbol;         // シンボル
        request.volume   =volume;                   // ポジションボリューム
        request.deviation=5;                       // 価格からの許容偏差
        request.magic    =EXPERT_MAGIC;             // ポジションのMagicNumber
        //--- ポジションタイプによる注文タイプと価格の設定
        if(type==POSITION_TYPE_BUY)
          {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
            request.type =ORDER_TYPE_SELL;
          }
        else
          {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
            request.type =ORDER_TYPE_BUY;
          }
        //--- 決済情報の出力
        PrintFormat("Close #%I64d %s %s",position_ticket,position_symbol,EnumToString(type));
        //--- リクエストの送信
        if(!OrderSend(request,result))
          PrintFormat("OrderSend error %d",GetLastError()); // リクエストの送信に失敗した場合、エラーコードを出力
        //--- 操作情報
        PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
        //---
      // }
    }
}