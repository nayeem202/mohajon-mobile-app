class ReportSummary {
  const ReportSummary({
    required this.label,
    required this.value,
    this.accent = 0xFF1E3A8A,
  });

  final String label;
  final String value;
  final int accent;
}

class ReportTableColumn {
  const ReportTableColumn({
    required this.key,
    required this.header,
    this.weight = 1,
    this.rightAlign = false,
  });

  final String key;
  final String header;
  final double weight;
  final bool rightAlign;
}

class ReportTableData {
  const ReportTableData({
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.rows,
    this.summaries = const [],
  });

  final String title;
  final String subtitle;
  final List<ReportTableColumn> columns;
  final List<Map<String, Object?>> rows;
  final List<ReportSummary> summaries;
}