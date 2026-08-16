class AppUser {
  final String id;
  final String username;
  final String password;
  final String name;
  final String role;
  final bool active;
  final String createdAt;
  final String assignedBarangay;

  const AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.role,
    this.active = true,
    this.createdAt = '',
    this.assignedBarangay = '',
  });
}
