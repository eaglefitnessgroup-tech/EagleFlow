import 'package:flutter/foundation.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

enum AuthBootstrapState {
  initializing,
  authenticatedDataLoading,
  authenticated,
  failed,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  final AuthRepository _repository;
  final Future<void> Function(AppUser user)? _onAuthenticated;
  final Future<void> Function()? _onSignedOut;

  AppUser? _currentUser;
  AuthBootstrapState _bootstrapState = AuthBootstrapState.initializing;
  bool _initializationInProgress = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthController(
    this._repository, {
    Future<void> Function(AppUser user)? onAuthenticated,
    Future<void> Function()? onSignedOut,
  }) : _onAuthenticated = onAuthenticated,
       _onSignedOut = onSignedOut;

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

    AppUser? restoredUser;
    try {
      restoredUser = await _repository.getCurrentUser();
    } catch (_) {
      restoredUser = null;
    }

    try {
      if (restoredUser == null) {
        _currentUser = null;
        await _onSignedOut?.call();
        _bootstrapState = AuthBootstrapState.unauthenticated;
      } else {
        _currentUser = restoredUser;
        _bootstrapState = AuthBootstrapState.authenticatedDataLoading;
        notifyListeners();
        try {
          await _onAuthenticated?.call(restoredUser);
          _bootstrapState = AuthBootstrapState.authenticated;
        } catch (error) {
          _errorMessage = 'Unable to load your workspace. Please try again.';
          _bootstrapState = AuthBootstrapState.failed;
        }
      }
    } catch (_) {
      _currentUser = null;
      await _onSignedOut?.call();
      _bootstrapState = AuthBootstrapState.unauthenticated;
    } finally {
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
        _bootstrapState = AuthBootstrapState.authenticatedDataLoading;
        notifyListeners();

        await _onAuthenticated?.call(result.user!);
        _bootstrapState = AuthBootstrapState.authenticated;

        return true;
      } else {
        _errorMessage = result.message;
        return false;
      }
    } catch (e) {
      if (_currentUser != null) {
        _bootstrapState = AuthBootstrapState.failed;
      }
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
      await _onSignedOut?.call();
      _bootstrapState = AuthBootstrapState.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }
}
