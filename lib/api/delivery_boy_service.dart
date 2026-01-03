import 'package:enterprise_pos/api/core/api_client.dart';

class DeliveryBoyService {
  final ApiClient _client;

  DeliveryBoyService({required String token}) : _client = ApiClient(token: token);

  void _ensureSuccess(Map<String, dynamic> res, String fallbackMessage) {
    if (res["success"] == true) return;
    throw Exception(res["message"] ?? fallbackMessage);
  }

  /// ✅ List delivery boys (role name only)
  Future<Map<String, dynamic>> getDeliveryBoys({
    int page = 1,
    int perPage = 20,
    String? search,
    int? branchId,
    String roleName = "delivery_boy", // change if your role name differs
  }) async {
    final query = <String, String>{
      "page": page.toString(),
      "per_page": perPage.toString(),
      "role": roleName, // ✅ role name filter only
      if (search != null && search.trim().isNotEmpty) "search": search.trim(),
      if (branchId != null) "branch_id": branchId.toString(),
    };

    final res = await _client.get("/users", query: query);
    _ensureSuccess(res, "Failed to load delivery boys");
    return res; // keep full response (pagination)
  }

  /// ✅ Detail header summary (orders_total, received_total, balance + delivery boy info)
  /// Expected backend: GET /delivery-boys/{id}/cash-summary
  Future<Map<String, dynamic>> getDeliveryBoyDetail({
    required int id,
    int? branchId,
    String? from, // YYYY-MM-DD (optional)
    String? to,   // YYYY-MM-DD (optional)
  }) async {
    final query = <String, String>{
      if (branchId != null) "branch_id": branchId.toString(),
      if (from != null && from.isNotEmpty) "from": from,
      if (to != null && to.isNotEmpty) "to": to,
    };

    final res = await _client.get("/delivery-boys/$id/cash-summary", query: query);
    _ensureSuccess(res, "Failed to load delivery boy detail");
    return res;
  }

  /// ✅ Orders tab (Sale records)
  /// Expected backend: GET /delivery-boys/{id}/orders
  Future<Map<String, dynamic>> getDeliveryBoyOrders({
    required int id,
    int page = 1,
    int perPage = 10,
    int? branchId,
    String? from, // optional
    String? to,   // optional
  }) async {
    final query = <String, String>{
      "page": page.toString(),
      "per_page": perPage.toString(),
      if (branchId != null) "branch_id": branchId.toString(),
      if (from != null && from.isNotEmpty) "from": from,
      if (to != null && to.isNotEmpty) "to": to,
    };

    final res = await _client.get("/delivery-boys/$id/orders", query: query);
    _ensureSuccess(res, "Failed to load delivery boy orders");
    return res;
  }

  /// ✅ Received tab (DeliveryBoyReceived records)
  /// Expected backend: GET /delivery-boys/{id}/received
  Future<Map<String, dynamic>> getDeliveryBoyReceived({
    required int id,
    int page = 1,
    int perPage = 10,
    int? branchId,
    String? from, // optional
    String? to,   // optional
  }) async {
    final query = <String, String>{
      "page": page.toString(),
      "per_page": perPage.toString(),
      if (branchId != null) "branch_id": branchId.toString(),
      if (from != null && from.isNotEmpty) "from": from,
      if (to != null && to.isNotEmpty) "to": to,
    };

    final res = await _client.get("/delivery-boys/$id/received", query: query);
    _ensureSuccess(res, "Failed to load received entries");
    return res;
  }

  /// ✅ Create received entry (Receive modal)
  /// Expected backend: POST /delivery-boys/{id}/received
  Future<Map<String, dynamic>> createDeliveryBoyReceived({
    required int deliveryBoyId,
    required double amount,
    int? branchId,
    String method = "cash", // cash|bank
    String? reference,
    String? date, // YYYY-MM-DD optional (if your API supports)
  }) async {
    final body = <String, dynamic>{
      "amount": amount,
      "method": method,
      if (reference != null && reference.trim().isNotEmpty)
        "reference": reference.trim(),
      if (branchId != null) "branch_id": branchId,
      if (date != null && date.isNotEmpty) "date": date,
    };

    final res = await _client.post("/delivery-boys/$deliveryBoyId/received", body: body);
    _ensureSuccess(res, "Failed to create received entry");
    return res;
  }
}
