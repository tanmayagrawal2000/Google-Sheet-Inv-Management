// Basic tests for the inventory app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inventory/core/utils/a1.dart';

void main() {
  test('A1.columnLetter maps indices to spreadsheet columns', () {
    expect(A1.columnLetter(0), 'A');
    expect(A1.columnLetter(25), 'Z');
    expect(A1.columnLetter(26), 'AA');
  });

  test('A1.wholeTab quotes the tab and spans columns', () {
    expect(A1.wholeTab('Piano', 7), "'Piano'!A:G");
    expect(A1.wholeTab("O'Brien", 2), "'O''Brien'!A:B");
  });

  testWidgets('MaterialApp builds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
