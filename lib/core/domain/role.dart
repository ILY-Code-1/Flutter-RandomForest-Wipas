/// User role stored in `users/{uid}.role` and `notifications.audience_roles`
/// (contract values: admin, manager, supervisor, viewer).
enum Role {
  admin('admin', 'Admin', 'Admin'),
  manajer('manager', 'Manajer', 'Manajer Warehouse'),
  supervisor('supervisor', 'Supervisor', 'Supervisor Operasional'),
  viewer('viewer', 'Viewer', 'Viewer · Tim DI');

  const Role(this.id, this.label, this.chipLabel);

  /// Value stored in Firestore.
  final String id;

  /// Short Indonesian label.
  final String label;

  /// Label on the Beranda role chip (from the design).
  final String chipLabel;

  static Role? tryParse(String? value) {
    for (final r in Role.values) {
      if (r.id == value) return r;
    }
    return null;
  }
}
