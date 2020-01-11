import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:ynab_csv/model.dart';

import 'crypto.dart';
import 'ext.dart';

mixin Transformer {
  Crypto get crypto;

  bool isForHeader(List<String> list);

  YnabApiTransaction from(List<String> list);

  String _createImportId(List<String> list) {
    return crypto.sha1AsBase64(list.where((it) => it.isNotNullOrBlank()).join());
  }
}

class RevolutTransformer with Transformer {
  final String fileName;
  final Map<String, String> accounts;
  @override
  final Crypto crypto;

  static final _inputDateFormatWithoutYear = DateFormat('d MMMM');
  static final _inputDateFormatWithYear = DateFormat('d MMMM yyyy');
  static final _outputDateFormat = DateFormat('yyyy-MM-dd');
  static final _yearInFilenameRegex = RegExp(r'\d{4}');

  RevolutTransformer({
    @required this.fileName,
    @required this.accounts,
    @required this.crypto,
  });

  @override
  bool isForHeader(List<String> list) =>
      list[RevolutColumn.completedDate.index].equalsIgnoreCase('Completed Date') &&
      list[RevolutColumn.paidOut.index].equalsIgnoreCase('Paid Out (EUR)') &&
      list[RevolutColumn.paidIn.index].equalsIgnoreCase('Paid In (EUR)') &&
      list[RevolutColumn.reference.index].equalsIgnoreCase('Reference');

  @override
  YnabApiTransaction from(List<String> list) {
    final account = accounts['Revolut'];
    if (account == null) throw 'Revolut account not found';
    return YnabApiTransaction(
      accountId: account,
      date: _createDate(list[RevolutColumn.completedDate.index]),
      amount: _createAmount(list[RevolutColumn.paidOut.index], list[RevolutColumn.paidIn.index]),
      payeeName: list[RevolutColumn.reference.index].trim(),
      importId: _createImportId(list),
      cleared: 'cleared',
    );
  }

  int _createAmount(String outAmount, String inAmount) {
    final isOutgoing = outAmount.isNotNullOrBlank();
    final amount = isOutgoing ? outAmount : inAmount;
    final numeric = double.parse(amount.replaceAll('\.', '').replaceFirst(',', '.'));
    final millis = (numeric * 1000).round();
    return isOutgoing ? -millis : millis;
  }

  String _createDate(String dateString) {
    final formatted = _inputDateFormatWithoutYear.parse(dateString);

    int year;
    try {
      year = _inputDateFormatWithYear.parse(dateString).year;
    } catch (e) {
      try {
        final yearInFileName = _yearInFilenameRegex.allMatches(fileName).toList()[1].group(0);
        year = int.parse(yearInFileName);
      } catch (e) {
        print('No year found in filename, using current');
        year = DateTime.now().year;
      }
    }

    return _outputDateFormat.format(DateTime(year, formatted.month, formatted.day));
  }
}

enum RevolutColumn {
  //Completed Date;Reference;Paid Out (EUR);Paid In (EUR);Exchange Out;Exchange In; Balance (EUR);Exchange Rate;Category
  completedDate,
  reference,
  paidOut,
  paidIn,
  exchangeOut,
  exchangeIn,
  balance,
  exchangeRate,
  category,
}

class KbcAccountTransformer with Transformer {
  static final _inputDateFormat = DateFormat('dd/MM/yyyy');
  static final _outputDateFormat = DateFormat('yyyy-MM-dd');

  // named groups are not supported in google apps script, so using named groups instead
  static final _payeeMemoRegexps = [
    PayeeMemoRegex(
      RegExp(r'(CREDITOR|SCHULDEISER)[ :]*(.*) (CREDITOR|SCHULDEISER).*(MEDEDELING|REFERENCE)[ :]*(.*)'),
      payee: 2,
      memo: 5,
    ),
    PayeeMemoRegex(
      RegExp(r'(TIME|UUR), (.*) (MET KBC|WITH KBC).*?[X \d]{4,}(.*)'),
      payee: 2,
      memo: 4,
    ),
    PayeeMemoRegex(
      RegExp(r'((CHARGE|BIJDRAGE) [\d-]{10}.*[\d-]{10}).*(KBC.*?) (PART|GEDEELTE)'),
      payee: 3,
      memo: 1,
    ),
    PayeeMemoRegex(
      RegExp(r'(.*?)[ ]*\d{2}-\d{2} (.*\d{3}-\d{7}-\d{2})'),
      payee: 2,
      memo: 1,
    ),
    PayeeMemoRegex(
      RegExp(r'(CASH WITHDRAWAL|GELDOPNEMING).*\d{2}-\d{2}(.*)'),
      payee: 1,
      memo: 2,
    ),
    PayeeMemoRegex(
      RegExp(r'(MOBILE PAYMENT|MOBIELE BETALING).*((DATE|DATUM).*)'),
      payee: 1,
      memo: 2,
    ),
  ];

  final Map<String, String> accounts;
  @override
  final Crypto crypto;

  KbcAccountTransformer({
    @required this.accounts,
    @required this.crypto,
  });

  @override
  bool isForHeader(List<String> list) =>
      (list[KbcAccountColumn.accountNumber.index].equalsIgnoreCase('Rekeningnummer') &&
          list[KbcAccountColumn.transactionDate.index].equalsIgnoreCase('Datum') &&
          list[KbcAccountColumn.description.index].equalsIgnoreCase('Omschrijving') &&
          list[KbcAccountColumn.amount.index].equalsIgnoreCase('Bedrag') &&
          list[KbcAccountColumn.counterPartyName.index].equalsIgnoreCase('Naam tegenpartij') &&
          list[KbcAccountColumn.referenceFree.index].equalsIgnoreCase('vrije mededeling')) ||
      (list[KbcAccountColumn.accountNumber.index].equalsIgnoreCase('Account number') &&
          list[KbcAccountColumn.transactionDate.index].equalsIgnoreCase('Date') &&
          list[KbcAccountColumn.description.index].equalsIgnoreCase('Description') &&
          list[KbcAccountColumn.amount.index].equalsIgnoreCase('Amount') &&
          list[KbcAccountColumn.counterPartyName.index].equalsIgnoreCase('Counterparty name') &&
          list[KbcAccountColumn.referenceFree.index].equalsIgnoreCase('Free-format reference'));

  @override
  YnabApiTransaction from(List<String> list) {
    final payeeAndMemo = _determinePayeeAndMemo(
      originalPayee: list[KbcAccountColumn.counterPartyName.index],
      originalDescription: list[KbcAccountColumn.description.index],
      originalMemo: list[KbcAccountColumn.referenceFree.index],
    );

    final account = accounts[list[KbcAccountColumn.accountNumber.index].replaceAll(' ', '')];
    if (account == null) throw 'Account ${list[KbcAccountColumn.accountNumber.index]} not found';
    return YnabApiTransaction(
      accountId: account,
      amount: _createAmount(list[KbcAccountColumn.amount.index]),
      date: _createDate(list[KbcAccountColumn.transactionDate.index]),
      payeeName: payeeAndMemo.payee,
      importId: _createImportId(list),
      memo: payeeAndMemo.memo,
      cleared: 'cleared',
    );
  }

  int _createAmount(String amount) {
    final numeric = double.parse(amount.replaceAll('\.', '').replaceFirst(',', '.'));
    final millis = (numeric * 1000).round();
    return millis;
  }

  String _createDate(String dateString) {
    final formatted = _inputDateFormat.parse(dateString);
    return _outputDateFormat.format(DateTime(formatted.year, formatted.month, formatted.day));
  }

  PayeeMemo _determinePayeeAndMemo({String originalPayee, String originalMemo, String originalDescription}) {
    if (originalPayee.isNotNullOrBlank()) {
      return PayeeMemo(payee: originalPayee, memo: originalMemo);
    }

    for (final regexConf in _payeeMemoRegexps) {
      final match = regexConf.regex.firstMatch(originalDescription);
      if (match != null) {
        return PayeeMemo(payee: match.group(regexConf.payee), memo: match.group(regexConf.memo));
      }
    }

    return PayeeMemo(payee: originalDescription, memo: originalMemo);
  }
}

class PayeeMemoRegex {
  final RegExp regex;
  final int payee;
  final int memo;

  PayeeMemoRegex(this.regex, {this.payee, this.memo});
}

class PayeeMemo {
  String payee;
  String memo;

  PayeeMemo({this.memo, this.payee});

  @override
  String toString() {
    return 'PayeeMemo{payee: $payee, memo: $memo}';
  }
}

enum KbcAccountColumn {
  accountNumber,
  categoryName,
  name,
  currency,
  statementNumber,
  transactionDate,
  description,
  valueDate,
  amount,
  balance,
  credit,
  debit,
  counterPartyAccount,
  counterPartyBic,
  counterPartyName,
  counterPartyAddress,
  referenceStandardFormat,
  referenceFree,
}

class KbcCreditCardTransformer with Transformer {
  static final _inputDateFormat = DateFormat('dd/MM/yyyy');
  static final _outputDateFormat = DateFormat('yyyy-MM-dd');

  final Map<String, String> accounts;
  @override
  final Crypto crypto;

  KbcCreditCardTransformer({
    @required this.accounts,
    @required this.crypto,
  });

  @override
  bool isForHeader(List<String> list) =>
      (list[KbcCCColumn.card.index].equalsIgnoreCase('credit card') &&
          list[KbcCCColumn.transactionDate.index].equalsIgnoreCase('date transaction') &&
          list[KbcCCColumn.amountInEUR.index].equalsIgnoreCase('amount in EUR') &&
          list[KbcCCColumn.merchant.index].equalsIgnoreCase('Merchant') &&
          list[KbcCCColumn.explanation.index].equalsIgnoreCase('explanation')) ||
      (list[KbcCCColumn.card.index].equalsIgnoreCase('kredietkaart') &&
          list[KbcCCColumn.transactionDate.index].equalsIgnoreCase('datum verrichting') &&
          list[KbcCCColumn.amountInEUR.index].equalsIgnoreCase('bedrag in EUR') &&
          list[KbcCCColumn.merchant.index].equalsIgnoreCase('Handelaar') &&
          list[KbcCCColumn.explanation.index].equalsIgnoreCase('toelichting'));

  @override
  YnabApiTransaction from(List<String> list) {
    var accountInCsv = list[KbcAccountColumn.accountNumber.index];

    if (accountInCsv.isNullOrBlank()) {
      // Most probably the repayment. Ignoring
      return null;
    }

    final account = accounts[accountInCsv.replaceAll(' ', '')];
    if (account == null) throw 'Account ${accountInCsv} not found';

    return YnabApiTransaction(
      accountId: account,
      amount: _createAmount(list[KbcCCColumn.amountInEUR.index]),
      payeeName: list[KbcCCColumn.merchant.index],
      memo: list[KbcCCColumn.explanation.index],
      date: _createDate(list[KbcCCColumn.transactionDate.index]),
      importId: _createImportId(list),
      cleared: 'cleared',
    );
  }

  int _createAmount(String amount) {
    final numeric = double.parse(amount.replaceAll('\.', '').replaceFirst(',', '.'));
    final millis = (numeric * 1000).round();
    return millis;
  }

  String _createDate(String dateString) {
    final formatted = _inputDateFormat.parse(dateString);
    return _outputDateFormat.format(DateTime(formatted.year, formatted.month, formatted.day));
  }
}

enum KbcCCColumn {
  card,
  cardHolder,
  billingStatement,
  transactionDate,
  settlementDate,
  amount,
  credit,
  debit,
  currency,
  price,
  amountInEUR,
  transactionCost,
  merchant,
  location,
  country,
  explanation,
}
