/// Small helpers shared by all hand-written models (no codegen needed).
DateTime? parseDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String? dateToJson(DateTime? d) => d?.toUtc().toIso8601String();

/// Removes null values so PATCH/PUT bodies only contain provided fields.
Map<String, dynamic> compact(Map<String, dynamic> m) =>
    m..removeWhere((_, v) => v == null);

T enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  if (raw == null) return fallback;
  final s = raw.toString().toLowerCase();
  for (final v in values) {
    if (v.name.toLowerCase() == s) return v;
  }
  return fallback;
}
