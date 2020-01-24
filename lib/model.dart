import 'dart:math';

import 'package:meta/meta.dart';

class YnabApiTransaction {
  String accountId;
  String date;
  int amount;
  String payeeName;
  String memo;
  String cleared;
  String importId;

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'date': date,
        'amount': amount,
        'payee_name': payeeName.trim().substring(0, min(100, payeeName.trim().length)),
        'memo': memo.trim(),
        'cleared': cleared,
        'import_id': importId,
      };

  YnabApiTransaction({
    @required this.accountId,
    @required this.date,
    @required this.amount,
    this.payeeName,
    this.memo,
    this.cleared,
    this.importId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YnabApiTransaction &&
          runtimeType == other.runtimeType &&
          accountId == other.accountId &&
          date == other.date &&
          amount == other.amount &&
          payeeName == other.payeeName &&
          memo == other.memo &&
          cleared == other.cleared &&
          importId == other.importId;

  @override
  int get hashCode =>
      accountId.hashCode ^
      date.hashCode ^
      amount.hashCode ^
      payeeName.hashCode ^
      memo.hashCode ^
      cleared.hashCode ^
      importId.hashCode;

  @override
  String toString() {
    return 'YnabApiTransaction{accountId: $accountId, date: $date, amount: $amount, payeeName: $payeeName, memo: $memo, cleared: $cleared, importId: $importId}';
  }
}
