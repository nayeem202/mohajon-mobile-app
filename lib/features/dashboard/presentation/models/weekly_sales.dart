class WeeklySalesData {
  const WeeklySalesData({
    required this.dayLabel,
    required this.fullDayName,
    required this.sales,
  });

  final String dayLabel;
  final String fullDayName;
  final double sales;

  static List<WeeklySalesData> demoData() {
    return const [
      WeeklySalesData(dayLabel: 'Sun', fullDayName: 'Sunday', sales: 2100),
      WeeklySalesData(dayLabel: 'Mon', fullDayName: 'Monday', sales: 3500),
      WeeklySalesData(dayLabel: 'Tue', fullDayName: 'Tuesday', sales: 5200),
      WeeklySalesData(dayLabel: 'Wed', fullDayName: 'Wednesday', sales: 4700),
      WeeklySalesData(dayLabel: 'Thu', fullDayName: 'Thursday', sales: 6900),
      WeeklySalesData(dayLabel: 'Fri', fullDayName: 'Friday', sales: 8200),
      WeeklySalesData(dayLabel: 'Sat', fullDayName: 'Saturday', sales: 6100),
    ];
  }
}
