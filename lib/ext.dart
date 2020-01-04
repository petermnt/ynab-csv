import 'dart:convert';
import 'dart:io';

extension StringExt on String {
  bool isNullOrBlank() => this == null || trim().isEmpty;

  bool isNotNullOrBlank() => !isNullOrBlank();

  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}

extension FileExt on File {
  String read() {
    for (final encoding in [utf8, latin1, ascii]) {
      try {
        return readAsStringSync(encoding: encoding);
      } catch (e) {
        print("Can't read file as ${encoding.name}, Error: ${e}\nTrying next encoding");
      }
    }

    throw "Can't read file";
  }
}
