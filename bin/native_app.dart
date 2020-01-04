import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:ynab_csv/api.dart';
import 'package:ynab_csv/crypto.dart';
import 'package:ynab_csv/ext.dart';
import 'package:ynab_csv/lib.dart';

const forceArg = 'force';
const fileArg = 'input-file';
const configFileArg = 'account-json';
const helpArg = 'help';
const dryRunArg = 'dryRun';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(fileArg, help: 'Required File path', abbr: 'i')
    ..addOption(configFileArg, help: 'Required Config json path', abbr: 'c')
    ..addFlag(forceArg, abbr: 'f', negatable: false, help: 'Force mode. Does not add a import-id.')
    ..addFlag(dryRunArg, abbr: 'd', negatable: false, help: 'Dry-run. Prints JSON.')
    ..addFlag(helpArg, abbr: 'h', negatable: false, help: 'Displays this help information.');

  final args = parser.parse(arguments);
  if (args[helpArg]) {
    stdout.writeln(parser.usage);
  } else {
    final String fileName = args[fileArg];
    final String configFileName = args[configFileArg];
    final bool dryRun = args[dryRunArg];
    final bool force = args[forceArg];

    if (fileName == null || configFileName == null) {
      stderr.writeln('ERROR: Missing fields');
      stderr.writeln(parser.usage);
      exit(2);
    }

    final configJson = jsonDecode(File(configFileName).read());
    final csv = File(fileName).read();

    final handler = YnabHandler(
      crypto: NativeCrypto(),
      fileName: fileName,
      accounts: configJson['accounts'].cast<String, String>(),
    );

    final transactions = handler.convertToTransactions(csv, force: force);

    if (dryRun) {
      print(jsonEncode(transactions));
    } else {
      await send(
        list: transactions,
        budgetId: configJson['budgetId'],
        accessToken: configJson['authToken'],
      );
    }
  }

  exit(exitCode);
}

class NativeCrypto with Crypto {
  @override
  String sha1AsBase64(String input) => base64.encode(sha1.convert(utf8.encode(input)).bytes);
}
