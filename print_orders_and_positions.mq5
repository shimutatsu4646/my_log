#define EXPERT_MAGIC 200 // エキスパートアドバイザのMagicNumber

void OnStart()
{
  int positions_total=PositionsTotal(); // 保有ポジション数
  Print("ポジション数", positions_total);
  for(int i=positions_total-1; i>=0; i--)
    {
      ulong  ticket=PositionGetTicket(i);
      string symbol=PositionGetString(POSITION_SYMBOL);
      ulong  magic=PositionGetInteger(POSITION_MAGIC);
      double volume=PositionGetDouble(POSITION_VOLUME);
      int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      PrintFormat("#ticket: %I64u symbol: %s type:%s volume: %.2f open_price：%s magic：[%I64d]",
        ticket,
        symbol,
        EnumToString(type),
        volume,
        DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits),
        magic
      );
    }

  int orders_total=OrdersTotal(); // 保有未決注文数
  Print("注文数", orders_total);
  for(int i=orders_total-1; i>=0; i--)
    {
      //--- 注文プロパティを返す
      ulong ticket = OrderGetTicket(i);
      string symbol       =OrderGetString(ORDER_SYMBOL);
      ulong magic   =OrderGetInteger(ORDER_MAGIC);
      double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
      int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      PrintFormat("#ticket: %I64u symbol: %s type:%s volume: %.2f open_price：%s magic：[%I64d]",
        ticket,
        symbol,
        EnumToString(type),
        volume,
        DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN),digits),
        magic
      );
    }
}