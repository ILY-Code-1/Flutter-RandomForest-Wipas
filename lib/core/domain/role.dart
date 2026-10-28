/// User role stored in `users/{uid}.role`.
enum Role {
  admin('admin', 'Admin'),
  manajer('manajer', 'Manajer'),
  supervisor('supervisor', 'Supervisor'),
  viewer('viewer', 'Viewer');

  const Role(this.id, this.label);

  /// Value stored in Firestore.
  final String id;

  /// Short Indonesian label.
  final String label;

  static Role? tryParse(String? value) {
    for (final r in Role.values) {
      if (r.id == value) return r;
    }
    return null;
  }
}
