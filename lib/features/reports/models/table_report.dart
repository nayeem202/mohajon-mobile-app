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
  });

  final String title;
  final String subtitle;
  final List<ReportTableColumn> columns;
  final List<Map<String, Object?>> rows;
}