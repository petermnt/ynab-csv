import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model.dart';

Future<void> send({List<YnabApiTransaction> list, String budgetId, String accessToken}) async {
  final response = await http.post(
    'https://api.youneedabudget.com/v1/budgets/$budgetId/transactions',
    headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
    body: jsonEncode({'transactions': list}),
  );

  if (response.statusCode != 201) {
    throw 'Error ${response.body}';
  } else {
    print('Success');
  }
}
