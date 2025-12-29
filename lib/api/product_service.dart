import 'dart:convert';
import 'dart:io';

import 'package:enterprise_pos/api/core/api_client.dart';
import 'package:http/http.dart' as http;

class ProductService {
  final ApiClient _client;

  ProductService({required String token}) : _client = ApiClient(token: token);

  /// Get all products with pagination & search
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int per_page = 20,
    String? search,
    int? vendorId,
  }) async {
    final queryParams = {
      "page": page.toString(),
      "per_page": per_page.toString(),
      if (search != null && search.isNotEmpty) "search": search,
      if (vendorId != null) "vendor_id": vendorId.toString(),
    };
    return await _client.get("/products", query: queryParams);
  }

  /// Create a new product
  Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> product,
  ) async {
    final res = await _client.post("/products", body: product);
    // API sometimes wraps inside "data"
    return res["data"] ?? res;
  }

  /// Update existing product
  Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> product,
  ) async {
    return await _client.put("/products/$id", body: product);
  }

  /// ✅ Create product with image (multipart/form-data)
  Future<Map<String, dynamic>> createProductWithImage(
    Map<String, dynamic> product, {
    required File imageFile,
  }) async {
    final uri = Uri.parse("${ApiClient.baseUrl}/products");

    final req = http.MultipartRequest("POST", uri);

    // IMPORTANT: don't set Content-Type manually in multipart
    req.headers.addAll({
      "Accept": "application/json",
      if (_client.token != null) "Authorization": "Bearer ${_client.token}",
    });

    _fillMultipartFields(req, product);

    req.files.add(await http.MultipartFile.fromPath("image", imageFile.path));

    final streamed = await req.send();
    final bodyStr = await streamed.stream.bytesToString();
    final decoded = jsonDecode(bodyStr);

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded["data"] ?? decoded;
    }
    throw Exception(decoded["message"] ?? "Upload failed: $bodyStr");
  }

  /// ✅ Update product with image (multipart/form-data)
  /// Laravel: use POST + _method=PUT for multipart
  Future<Map<String, dynamic>> updateProductWithImage(
    int id,
    Map<String, dynamic> product, {
    required File imageFile,
  }) async {
    final uri = Uri.parse("${ApiClient.baseUrl}/products/$id");

    final req = http.MultipartRequest("POST", uri);

    req.headers.addAll({
      "Accept": "application/json",
      if (_client.token != null) "Authorization": "Bearer ${_client.token}",
    });

    req.fields["_method"] = "PUT";

    _fillMultipartFields(req, product);

    req.files.add(await http.MultipartFile.fromPath("image", imageFile.path));

    final streamed = await req.send();
    final bodyStr = await streamed.stream.bytesToString();
    final decoded = jsonDecode(bodyStr);

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded["data"] ?? decoded;
    }
    throw Exception(decoded["message"] ?? "Upload failed: $bodyStr");
  }

  /// Get product by barcode
  // Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
  //   final res = await _client.get("/products/by-barcode/$barcode");
  //   return res["data"];
  // }

  Future<Map<String, dynamic>?> getProductByBarcode(
    String barcode, {
    int? vendorId,
  }) async {
    final safeBarcode = Uri.encodeComponent(barcode.trim());
    final path = vendorId != null
        ? "/products/by-barcode/$safeBarcode/$vendorId"
        : "/products/by-barcode/$safeBarcode";

    try {
      final res = await _client.get(path);
      final data = res["data"];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      // If your ApiClient throws typed errors with status codes, you can
      // check for 404 here and return null. Otherwise, just swallow and return null.
      // Example:
      // if (e is ApiError && e.statusCode == 404) return null;
      return null;
    }
  }

  /// Delete product
  Future<void> deleteProduct(int id) async {
    await _client.delete("/products/$id");
  }

  // --------------------
  // Helper
  // --------------------
  void _fillMultipartFields(
    http.MultipartRequest req,
    Map<String, dynamic> product,
  ) {
    product.forEach((key, value) {
      if (value == null) return;

      if (value is bool) {
        req.fields[key] = value ? "1" : "0";
      } else if (value is num || value is String) {
        req.fields[key] = value.toString();
      } else {
        // List/Map like branch_stocks
        req.fields[key] = jsonEncode(value);
      }
    });
  }
}
