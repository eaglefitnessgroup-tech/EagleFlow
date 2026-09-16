import '../../authentication/domain/app_user.dart';

class SalespersonNameResolver {
  SalespersonNameResolver._();

  static String resolve({
    required String salespersonId,
    AppUser? currentUser,
    Iterable<AppUser> profiles = const [],
  }) {
    if (currentUser != null && currentUser.id == salespersonId) {
      return currentUser.name;
    }

    for (final profile in profiles) {
      if (profile.id == salespersonId) {
        return profile.name;
      }
    }

    return salespersonId;
  }
}
