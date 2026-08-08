import 'package:flutter/foundation.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repository;

  AppUser? _currentUser;
  bool _isInitializing = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthController(this._repository);

  AppUser? get currentUser => _currentUser;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSales => _currentUser?.isSales ?? false;

  // Permissions
  bool get canManageStock => _currentUser?.canManageStock ?? false;
  bool get canViewReports => _currentUser?.canViewReports ?? false;
  bool get canManageUsers => _currentUser?.canManageUsers ?? false;
  bool get canCancelAnyReservation =>
      _currentUser?.canCancelAnyReservation ?? false;

  @visibleForTesting
  void setCurrentUserForTesting(AppUser? user) {
    _currentUser = user;
  }

  Future<void> initialize() async {
    if (_isInitializing) return;

    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.getCurrentUser();
    } catch (e) {
      _currentUser = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.login(
        username: username,
        password: password,
      );

      if (result.success && result.user != null) {
        _currentUser = result.user;

        return true;
      } else {
        _errorMessage = result.message;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Unable to complete authentication. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (e) {
      // Ignored for logout
    } finally {
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    }
  }
}
