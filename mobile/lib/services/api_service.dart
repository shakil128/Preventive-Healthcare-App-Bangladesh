/// Talks to the Spring Boot backend using **dio** (same package you use in the
/// PKSF login screen). The app is offline-first, so callers treat every method
/// as best-effort: on failure the local SQLite store stays the source of truth.
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../domain/models.dart';

class ApiService {
  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Content-Type': 'application/json'},
        ));

  final Dio _dio;

  /// DB-backed login. Returns {role, profile} on success, **null** when the
  /// server said the credentials are wrong (401), and **throws** when the
  /// server is unreachable — so callers can tell "wrong password" apart from
  /// "offline" (same DioException pattern as the PKSF login screen).
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final res = await _dio.post('/api/auth/login', data: {
        'username': username,
        'password': password,
      });
      if (res.statusCode == 200 && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return null;
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode == 401) {
        return null; // invalid username/password
      }
      rethrow; // network problem — caller decides (offline fallback)
    }
  }

  Future<List<Beneficiary>> beneficiaries() async {
    final res = await _dio.get('/api/beneficiaries');
    final list = res.data as List;
    return list
        .map((e) => Beneficiary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Worker>> workers() async {
    final res = await _dio.get('/api/workers');
    final list = res.data as List;
    return list
        .map((e) => Worker.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Onboard a field officer on the server. The backend creates the Worker and
  /// the login **User** row (persisted in PostgreSQL) and generates the
  /// username/password, returning them so the portal shows the admin the exact
  /// credentials the officer signs in with. Throws on network failure so the
  /// caller can tell the admin the account was *not* created offline.
  Future<({Worker worker, String username, String password})> onboardWorker({
    required String name,
    required int age,
    required String phone,
    required String nid,
    required String union,
    required WorkerRole role,
  }) async {
    final res = await _dio.post('/api/workers', data: {
      'name': name,
      'age': age,
      'phone': phone,
      'nid': nid,
      'union': union,
      'role': role.label, // backend enum names are upper-case: FWA/FWV/CHCP/HA
    });
    final body = Map<String, dynamic>.from(res.data as Map);
    return (
      worker: Worker.fromJson(Map<String, dynamic>.from(body['worker'] as Map)),
      username: body['username'] as String,
      password: body['password'] as String,
    );
  }

  /// Push the batched offline queue; returns the ref ids the server acknowledged.
  Future<Set<String>> sync(List<SyncQueueItem> items) async {
    final res = await _dio.post('/api/sync', data: {
      'items': items.map((i) => i.toJson()).toList(),
    });
    final body = res.data as Map;
    final acked = (body['acknowledgedRefIds'] as List?) ?? const [];
    return acked.map((e) => e as String).toSet();
  }
}
