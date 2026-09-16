import 'package:flutter/foundation.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

enum AuthBootstrapState { initializing, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final AuthRepository _repository;

  AppUser? _currentUser;
  AuthBootstrapState _bootstrapState = AuthBootstrapState.initializing;
  bool _initializationInProgress = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthController(this._repository);

  AppUser? get currentUser => _currentUser;
  AuthBootstrapState get bootstrapState => _bootstrapState;
  bool get isInitializing => _bootstrapState == AuthBootstrapState.initializing;
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
    _bootstrapState = user == null
        ? AuthBootstrapState.unauthenticated
        : AuthBootstrapState.authenticated;
  }

  Future<void> initialize() async {
    if (_initializationInProgress) return;

    _initializationInProgress = true;
    _bootstrapState = AuthBootstrapState.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.getCurrentUser();
    } catch (e) {
      _currentUser = null;
    } finally {
      _bootstrapState = _currentUser == null
          ? AuthBootstrapState.unauthenticated
          : AuthBootstrapState.authenticated;
      _initializationInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.login(email: email, password: password);

      if (result.success && result.user != null) {
        _currentUser = result.user;
        _bootstrapState = AuthBootstrapState.authenticated;

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
      _bootstrapState = AuthBootstrapState.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }
}
