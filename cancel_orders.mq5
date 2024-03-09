#define EXPERT_MAGIC 101 // エキスパートアドバイザのMagicNumber
//+------------------------------------------------------------------+
//| 未決注文の削除                                                      |
//+------------------------------------------------------------------+
void OnStart()
{
//--- リクエストと結果の宣言と初期化
  MqlTradeRequest request={};
  MqlTradeResult  result={};
  int total=OrdersTotal(); // 保有未決注文数
  Print("キャンセル注文数",total);
//--- 全ての保有未決注文を取捨
  for(int i=total-1; i>=0; i--)
    {
    ulong  order_ticket=OrderGetTicket(i);                   // 注文チケット
    ulong  magic=OrderGetInteger(ORDER_MAGIC);               // 注文のMagicNumber
    //--- MagicNumberが一致している場合
    // if(magic==EXPERT_MAGIC)
      // {
        //--- リクエストと結果の値のゼロ化
        ZeroMemory(request);
        ZeroMemory(result);
        //--- 操作パラメータの設定
        request.action=TRADE_ACTION_REMOVE;                   // 取引操作タイプ
        request.order = order_ticket;                         // 注文チケット
        //--- リクエストの送信
        if(!OrderSend(request,result))
          PrintFormat("OrderSend error %d",GetLastError()); // リクエストの送信に失敗した場合、エラーコードを出力する
        //--- 操作情報
        PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
      // }
    }
}