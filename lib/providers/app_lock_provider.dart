import 'dart:async';
import 'package:flutter/material.dart';
import 'package:counter_iq/api/app_lock_service.dart';

class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _isLocked = false;
  bool _isUnlockedByPasskey = false;
  bool _showAlert = false;
  bool _alertAlreadyShownThisCycle = false;
  bool _initialized = false;
  bool _isRequestInProgress = false;

  String _message = 'Application is locked.';
  String _passKey = '123456';
  int _remainingDays = 0;

  Timer? _timer;

  bool get isChecking => _isChecking;
  bool get isLocked => _isLocked;
  bool get isUnlockedByPasskey => _isUnlockedByPasskey;
  bool get showAlert => _showAlert;
  String get message => _message;
  String get passKey => _passKey;
  int get remainingDays => _remainingDays;

  bool get shouldShowLockScreen => _isLocked && !_isUnlockedByPasskey;

  bool get shouldShowExpiryAlert =>
      !_isLocked && _showAlert && !_alertAlreadyShownThisCycle;

  void init() {
    if (_initialized) return;
    _initialized = true;

    print("AppLockProvider init called");

    WidgetsBinding.instance.addObserver(this);

    checkStatus();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 3), (_) {
      print("3-hour app lock check triggered");
      checkStatus();
    });
  }

  Future<void> checkStatus() async {
    if (_isRequestInProgress) return;
    _isRequestInProgress = true;

    try {
      print("Checking app lock status...");
      final service = AppLockService();
      final res = await service.getAppLockStatus();
      print("App lock status: $res");

      _isLocked = res['is_locked'] == true;
      _message = res['message']?.toString() ?? 'Application is locked.';
      _passKey = res['pass_key']?.toString() ?? '123456';
      _showAlert = res['show_alert'] == true;
      _remainingDays = res['remaining_days'] ?? 0;

      if (_isLocked) {
        _isUnlockedByPasskey = false;
      }

      _alertAlreadyShownThisCycle = false;
      _isChecking = false;
      notifyListeners();
    } catch (e) {
      print("App lock check failed: $e");

      _isLocked = true;
      _isUnlockedByPasskey = false;
      _showAlert = false;
      _message =
          'Unable to verify application access. Please contact developer.';
      _passKey = '123456';
      _isChecking = false;

      notifyListeners();
    } finally {
      _isRequestInProgress = false;
    }
  }

  void unlockApp() {
    _isUnlockedByPasskey = true;
    notifyListeners();
  }

  void markAlertShown() {
    _alertAlreadyShownThisCycle = true;
    notifyListeners();
  }

  void clearTemporaryUnlock() {
    _isUnlockedByPasskey = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("Lifecycle changed: $state");

    if (state == AppLifecycleState.resumed) {
      checkStatus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
