class StaffRole {
  const StaffRole({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory StaffRole.fromJson(Map<String, dynamic> json) => StaffRole(
        id: (json['id'] ?? '') as String,
        code: (json['code'] ?? '') as String,
        name: (json['name'] ?? '') as String,
      );
}

class AppMenu {
  const AppMenu({
    required this.id,
    required this.code,
    required this.name,
    required this.section,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String name;
  final String section;
  final int sortOrder;

  factory AppMenu.fromJson(Map<String, dynamic> json) => AppMenu(
        id: (json['id'] ?? '') as String,
        code: (json['code'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        section: (json['section'] ?? '') as String,
        sortOrder: (json['sortOrder'] ?? 0) as int,
      );
}
