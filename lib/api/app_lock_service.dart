import 'package:counter_iq/api/core/api_client.dart';

class AppLockService {
  final ApiClient _client;

  AppLockService() : _client = ApiClient();

  Future<Map<String, dynamic>> getAppLockStatus() async {
    final res = await _client.post("/app-lock-status");

    if (res["success"] == true) {
      final data = res["data"] ?? {};

      return {
        "is_locked": data["is_locked"] == true,
        "message": data["message"]?.toString() ?? "Application is locked.",
        "pass_key": data["pass_key"]?.toString(),
        "show_alert": data["show_alert"] == true,
        "remaining_days": data["remaining_days"] is int
            ? data["remaining_days"]
            : int.tryParse(data["remaining_days"]?.toString() ?? "0") ?? 0,
      };
    }

    throw Exception(res["message"] ?? "Failed to fetch app lock status");
  }
}