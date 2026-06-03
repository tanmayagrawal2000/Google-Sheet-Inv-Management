/// Helpers for building A1 notation ranges used by the Sheets API.
class A1 {
  A1._();

  /// Converts a 0-based column index to its spreadsheet letter(s) (0 -> A,
  /// 25 -> Z, 26 -> AA).
  static String columnLetter(int index) {
    var n = index;
    final letters = <int>[];
    do {
      final remainder = n % 26;
      letters.add(65 + remainder);
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return String.fromCharCodes(letters.reversed);
  }

  /// Escapes a tab name for use inside single quotes in A1 notation.
  static String _quote(String tab) => "'${tab.replaceAll("'", "''")}'";

  /// A whole-tab range covering [columnCount] columns, e.g. `'Piano'!A:G`.
  static String wholeTab(String tab, int columnCount) {
    final lastCol = columnLetter(columnCount - 1);
    return '${_quote(tab)}!A:$lastCol';
  }

  /// The header row range for a tab, e.g. `'Piano'!A1:G1`.
  static String headerRow(String tab, int columnCount) {
    final lastCol = columnLetter(columnCount - 1);
    return '${_quote(tab)}!A1:${lastCol}1';
  }
}
