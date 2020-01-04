@JS()
library ynab_csv;

import 'dart:convert';
import 'dart:js';

import 'package:js/js.dart';
import 'package:ynab_csv/crypto.dart';
import 'package:ynab_csv/lib.dart';

@JS()
external set create(value);

void updateDart(String accountsJson, String fileName, String csv) {
  final handler = YnabHandler(
    accounts: jsonDecode(accountsJson).cast<String, String>(),
    fileName: fileName,
    crypto: GoogleAppsCrypto(),
  );
  var json = jsonEncode({'transactions': handler.convertToTransactions(csv)});

  context.callMethod('doCall', [json]);
}

void main() {
  create = allowInterop(updateDart);
}

class GoogleAppsCrypto with Crypto {
  @override
  String sha1AsBase64(String input) {
    return Utilities.base64Encode(Utilities.computeDigest(Utilities.SHA1, input));
  }
}
//   const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_1, input)
//  return Utilities.base64Encode(bytes)

@JS()
class Utilities {
  @JS('DigestAlgorithm.SHA_1')
  external static get SHA1;

  external static List<int> computeDigest(algorithm, value);

  external static String base64Encode(data);
}
