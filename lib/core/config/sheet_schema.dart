class SheetSchema {
  SheetSchema._();

  static const String issueLogTab = '_IssueLog';
  static const String damageLogTab = '_DamageLog';

  // ── Item columns (A–J, indices 0–9) ────────────────────────────────────────

  static const List<String> itemHeaders = <String>[
    'SNo', 'Detail', 'Firm Name', 'Price', 'Quantity',
    'ItemId', 'Notes', 'ImageUrl', 'Bill No', 'Bill Date',
  ];

  static const int itemColSNo = 0;
  static const int itemColDetail = 1;
  static const int itemColFirmName = 2;
  static const int itemColPrice = 3;
  static const int itemColQuantity = 4;
  static const int itemColItemId = 5;
  static const int itemColNotes = 6;
  static const int itemColImageUrl = 7;
  static const int itemColBillNo = 8;
  static const int itemColBillDate = 9;

  // ── Formula columns (K–N, indices 10–13) ───────────────────────────────────
  // App never reads these; they are written for human visibility in Sheets.

  static const List<String> formulaHeaders = ['Total', 'Issued', 'Damaged', 'Available'];
  static const int formulaColTotal = 10;     // K
  static const int formulaColIssued = 11;    // L
  static const int formulaColDamaged = 12;   // M
  static const int formulaColAvailable = 13; // N

  /// Summary block — always 2 columns after [formulaColAvailable] so adding
  /// new data or formula columns never displaces it.
  static int get summaryLabelCol => formulaColAvailable + 2; // currently P
  static int get summaryValueCol => formulaColAvailable + 3; // currently Q

  // ── Issue log columns ───────────────────────────────────────────────────────

  static const List<String> issueLogHeaders = <String>[
    'LogId', 'CategoryTab', 'ItemId', 'ItemDetail',
    'Quantity', 'Borrower', 'DateIssued', 'ExpectedReturn', 'DateReturned', 'Status',
  ];

  static const int logColLogId = 0;
  static const int logColCategoryTab = 1;
  static const int logColItemId = 2;
  static const int logColItemDetail = 3;
  static const int logColQuantity = 4;
  static const int logColBorrower = 5;
  static const int logColDateIssued = 6;
  static const int logColExpectedReturn = 7;
  static const int logColDateReturned = 8;
  static const int logColStatus = 9;

  static const String statusOpen = 'Open';
  static const String statusReturned = 'Returned';

  // ── Damage log columns ──────────────────────────────────────────────────────

  static const List<String> damageLogHeaders = <String>[
    'LogId', 'CategoryTab', 'ItemId', 'ItemDetail', 'Quantity', 'DamagedDate', 'Details', 'Status',
  ];

  static const int damageLogColLogId = 0;
  static const int damageLogColCategoryTab = 1;
  static const int damageLogColItemId = 2;
  static const int damageLogColItemDetail = 3;
  static const int damageLogColQuantity = 4;
  static const int damageLogColDamagedDate = 5;
  static const int damageLogColDetails = 6;
  static const int damageLogColStatus = 7;

  static const String damageStatusDamaged = 'Damaged';
  static const String damageStatusRepaired = 'Repaired';

  static const int firstDataRow = 2;
}
