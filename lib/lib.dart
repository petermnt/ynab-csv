import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:ynab_csv/crypto.dart';
import 'package:ynab_csv/ext.dart';
import 'package:ynab_csv/model.dart';
import 'package:ynab_csv/transformer.dart';

class YnabHandler {
  String fileName;
  Map<String, String> accounts;
  Crypto crypto;

  YnabHandler({
    @required this.fileName,
    @required this.accounts,
    @required this.crypto,
  });

  List<YnabApiTransaction> convertToTransactions(String csv, {bool force = false}) {
    final split = _splitCsv(csv);
    final sanitized = _sanitize(split);

    final transformers = [
      RevolutTransformer(fileName: fileName, accounts: accounts, crypto: crypto),
      KbcAccountTransformer(accounts: accounts, crypto: crypto),
      KbcCreditCardTransformer(accounts: accounts, crypto: crypto),
    ].cast<Transformer>();

    for (final transformer in transformers) {
      if (transformer.isForHeader(sanitized[0])) {
        return sanitized
            .sublist(1)
            .map(transformer.from)
            .where((it) => it != null)
            .map((t) => t..importId = force ? null : t.importId)
            .toList();
      }
    }

    throw 'No transformer found';
  }

  List<List<String>> _sanitize(Iterable<Iterable<String>> split) {
    return split
        .where((row) => !(row.isEmpty || row.every((e) => e.isNullOrBlank())))
        .map((row) => row.map((item) => item.isEmpty ? null : item.trim()).toList())
        .toList();
  }

  List<List<String>> _splitCsv(String rawCsv) {
    final rows = LineSplitter().convert(rawCsv);
    return rows.map((row) => row.split(';').toList()).toList();
  }
}
