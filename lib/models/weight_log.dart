class WeightLog {
  WeightLog({required this.loggedDate, required this.weightKg});

  final DateTime loggedDate;
  final double weightKg;

  factory WeightLog.fromRow(Map<String, dynamic> row) {
    return WeightLog(
      loggedDate: DateTime.parse(row['logged_date'] as String),
      weightKg: (row['weight_kg'] as num).toDouble(),
    );
  }
}

/// Formats [date] as the `date`-typed `logged_date` column expects
/// (`YYYY-MM-DD`, no time component).
String formatLoggedDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
