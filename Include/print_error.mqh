// エラー出力共通化
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
