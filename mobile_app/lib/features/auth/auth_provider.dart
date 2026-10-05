import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../core/api/api_client.dart';
import 'auth_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  bool _isLoading = false;

  UserModel? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.login(phone, password);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    String? email,
    required String password,
    required String role,
    String? accountType,
    String? companyName,
    String? companyRegNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.register(
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
        role: role,
        accountType: accountType,
        companyName: companyName,
        companyRegNumber: companyRegNumber,
      );
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Inarudisha mtumiaji aliyeingia awali (bila kuandika nenosiri tena)
  Future<bool> tryAutoLogin() async {
    final session = await ApiClient().readSession();
    if (session == null) return false;
    _user = UserModel(
      userId: session.userId,
      fullName: session.fullName,
      role: session.role,
      token: session.token,
    );
    _status = AuthStatus.authenticated;
    notifyListeners();
    return true;
  }

  /// Inasasisha jina baada ya kubadilisha wasifu (bila kuingia upya)
  void updateFullName(String fullName) {
    final current = _user;
    if (current == null) return;
    ApiClient().saveUserName(fullName);
    _user = UserModel(
      userId: current.userId,
      fullName: fullName,
      role: current.role,
      token: current.token,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
