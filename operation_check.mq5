//+------------------------------------------------------------------+
//|                                                          try.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

int OnInit()
{
  datetime zeroBarTime = iTime(_Symbol, PERIOD_M1, 0);
  datetime oneBarTime = iTime(_Symbol, PERIOD_M1, 1);
  Print("zeroBarTime: ", zeroBarTime);
  // → zeroBarTime: 2024.02.28 15:43:00
  Print("oneBarTime: ", oneBarTime);
  // →oneBarTime: 2024.02.28 15:42:00
  datetime zBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
  datetime oBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);
  Print("zBarTime: ", zBarTime);
  // → zeroBarTime: 2024.02.28 15:43:00
  Print("oBarTime: ", oBarTime);
  // →oneBarTime: 2024.02.28 15:42:00

  return(INIT_SUCCEEDED);
}

// void OnStart()
// {
  // double minVolume = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
	// double maxVolume = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
	// double stepVolume = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  // Print("minVolume value: ", minVolume);
  // Print("maxVolume value: ", maxVolume);
  // Print("stepVolume value: ", stepVolume);

  // int digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); // 小数点以下の桁数（精度）
  // int digits = Digits(); // 小数点以下の桁数（精度）
  // Print("digits: ", digits);

  // double point = Point();
  // Print("point: ", point);

  // double amount_currency_of_one_lot = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

  // Print("amount_currency_of_one_lot: ", amount_currency_of_one_lot);
  // double amount_currency_of_one_lot = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

  // Print("amount_currency_of_one_lot: ", amount_currency_of_one_lot);

  // Print("Symbol(): ", Symbol());

      // 対円ペアのシンボルを指定
    // string symbol = "EURJPY"; // EUR対JPYの例

    // // ティックデータを格納するための構造体
    // MqlTick tick;

    // // 最新のティックデータを取得
    // if(SymbolInfoTick(symbol, tick))
    // {
    //     // ask価格とbid価格の平均を取得して対円レートとして使用
    //     double rate = (tick.ask + tick.bid) / 2.0;
        
    //     // 結果を表示
    //     Print("対円レート: ", rate);
    // }
    // else
    // {
    //     // データ取得に失敗した場合のエラーメッセージ
    //     Print("対円レートの取得に失敗しました。");
    // }


  // string current_with_jpy;
  // StringAdd(settlement_currency, "JPY");
  // int length = StringLen(_Symbol);
  // string settlement_currency = StringSubstr(_Symbol, 3, length - 3);

  // Print("settlement_currency: ", settlement_currency);

// }

datetime lastBarTime = 0; // 最後に確認したバーの時間を格納する変数

void OnTick()
{
    datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0); // 現在のバーのオープン時間を取得
    if (currentBarTime != lastBarTime)
    {
        // 新しい足が確定した
        lastBarTime = currentBarTime; // 最後のバー時間を更新

        // ここに新しい足が確定した時の処理を記述
        Print("excellent, currentBarTime: ", currentBarTime);
    }
}
