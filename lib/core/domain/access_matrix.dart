import 'role.dart';

/// Access level of a role for a route. Controls a role may not use are hidden.
enum Access { full, readOnly, none }

/// Route paths used by the router and the access matrix.
class Routes {
  Routes._();
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/login/lupa';
  static const beranda = '/beranda';
  static const prediksi = '/prediksi';
  static const manpower = '/manpower';
  static const evaluasi = '/evaluasi';
  static const inputActual = '/input-actual';
  static const konfigurasi = '/konfigurasi';
  static const riwayat = '/riwayat';
  static const notifikasi = '/notifikasi';
  static const profil = '/profil';
  static const lainnya = '/lainnya';
  static const gallery = '/dev/gallery';

  static const public = {splash, login, forgotPassword};
}

/// Single source of truth for role-based access (see `docs/rbac_matrix.md`).
class AccessMatrix {
  AccessMatrix._();

  static const _f = Access.full;
  static const _r = Access.readOnly;
  static const _n = Access.none;

  static const Map<String, Map<Role, Access>> _table = {
    Routes.beranda: {Role.admin: _f, Role.manajer: _f, Role.supervisor: _f, Role.viewer: _r},
    Routes.prediksi: {Role.admin: _r, Role.manajer: _r, Role.supervisor: _r, Role.viewer: _r},
    Routes.manpower: {Role.admin: _f, Role.manajer: _f, Role.supervisor: _r, Role.viewer: _n},
    Routes.evaluasi: {Role.admin: _f, Role.manajer: _f, Role.supervisor: _n, Role.viewer: _r},
    Routes.inputActual: {Role.admin: _f, Role.manajer: _n, Role.supervisor: _f, Role.viewer: _n},
    Routes.konfigurasi: {Role.admin: _f, Role.manajer: _f, Role.supervisor: _n, Role.viewer: _n},
    Routes.riwayat: {Role.admin: _f, Role.manajer: _r, Role.supervisor: _r, Role.viewer: _r},
    Routes.notifikasi: {Role.admin: _f, Role.manajer: _f, Role.supervisor: _f, Role.viewer: _f},
    Routes.profil: {Role.admin: _f, Role.manajer: _f, Role.supervisor: _f, Role.viewer: _f},
    Routes.lainnya: {Role.admin: _f, Role.manajer: _f, Role.supervisor: _f, Role.viewer: _f},
  };

  /// Access for [role] on [path]. Public routes are always full; unknown
  /// routes are denied.
  static Access accessFor(Role role, String path) {
    if (Routes.public.contains(path)) return Access.full;
    return _table[path]?[role] ?? Access.none;
  }

  static bool canOpen(Role role, String path) => accessFor(role, path) != Access.none;
  static bool isReadOnly(Role role, String path) => accessFor(role, path) == Access.readOnly;

  /// Bottom navigation tabs in display order, filtered by role.
  static const allTabs = [Routes.beranda, Routes.prediksi, Routes.manpower, Routes.evaluasi, Routes.lainnya];
  static List<String> tabsFor(Role role) => allTabs.where((t) => canOpen(role, t)).toList();

  // Fine-grained capabilities used to hide controls.
  static bool canDecideManpower(Role role) => accessFor(role, Routes.manpower) == Access.full;
  static bool canInputActual(Role role) => canOpen(role, Routes.inputActual);
  static bool canEditConfig(Role role) => canOpen(role, Routes.konfigurasi);
  static bool canExportCsv(Role role) => role == Role.admin;
  static bool canSeeDecisions(Role role) => role != Role.viewer;
  static bool canSeeFeatureDrivers(Role role) => role != Role.supervisor;
  static bool canSeeManpower(Role role) => canOpen(role, Routes.manpower);
  static bool canSeeEvaluasi(Role role) => canOpen(role, Routes.evaluasi);
}
