/// Repository — the only module that mutates the local store. Every write also
/// pushes a record onto the sync queue so the offline → online flush is
/// centralized. Reads come from the local store (offline-first); a successful
/// sync reconciles with the backend.
import '../domain/models.dart';
import 'api_service.dart';
import 'local_db.dart';

class Repository {
  Repository({LocalDb? db, ApiService? api})
      : _db = db ?? LocalDb.instance,
        _api = api ?? ApiService();

  final LocalDb _db;
  final ApiService _api;

  ApiService get api => _api;

  /// Read-through: PostgreSQL is the source of truth. Fetch the authoritative
  /// list, refresh the local cache, and return it. If the backend is
  /// unreachable, fall back to the cached copy so the field app still works
  /// offline.
  Future<List<Beneficiary>> beneficiaries() async {
    try {
      final remote = await _api.beneficiaries();
      await _db.replaceBeneficiaries(remote);
      return remote;
    } catch (_) {
      return _db.beneficiaries();
    }
  }

  Future<List<Worker>> workers() async {
    try {
      final remote = await _api.workers();
      await _db.replaceWorkers(remote);
      return remote;
    } catch (_) {
      return _db.workers();
    }
  }

  Future<Beneficiary?> beneficiary(String id) => _db.beneficiary(id);
  Future<int> pendingCount() => _db.pendingCount();

  /// Write-through: register the beneficiary in PostgreSQL first, then cache the
  /// stored record. Throws on network failure so the UI can tell the officer the
  /// entry was not saved (rather than silently keeping a local-only ghost row).
  Future<void> addBeneficiary(Beneficiary b) async {
    final saved = await _api.registerBeneficiary(b);
    await _db.putBeneficiary(saved);
  }

  /// Record an ANC visit. The backend classifies the risk and persists the
  /// update in PostgreSQL; the returned record refreshes the cache.
  Future<void> recordAncVisit(String id, AncVisit visit) async {
    final updated = await _api.recordAncVisit(id, visit);
    await _db.putBeneficiary(updated);
  }

  Future<void> recordChildAssessment(String id, ChildAssessment assessment) async {
    final updated = await _api.recordChildAssessment(id, assessment);
    await _db.putBeneficiary(updated);
  }

  Future<void> addWorker(Worker w) async {
    await _db.putWorker(w);
    await _db.enqueue('worker', w.id, 'Onboarded ${w.name}');
  }

  /// Onboard a field officer through the backend so the User + Worker rows are
  /// created in PostgreSQL and the server-generated credentials come back. The
  /// worker is cached locally so the portal list updates immediately.
  Future<({Worker worker, String username, String password})> onboardWorker({
    required String name,
    required int age,
    required String phone,
    required String nid,
    required String union,
    required WorkerRole role,
  }) async {
    final result = await _api.onboardWorker(
      name: name, age: age, phone: phone, nid: nid, union: union, role: role);
    await _db.putWorker(result.worker);
    return result;
  }

  /// Flush the sync queue to the backend, clearing only acknowledged records.
  /// Returns the number flushed. Falls back to a local clear when offline so the
  /// UX still advances (the design reference simulated the round-trip).
  Future<int> flushSyncQueue() async {
    final items = await _db.pendingItems();
    if (items.isEmpty) return 0;
    try {
      final acked = await _api.sync(items);
      await _db.clearAcknowledged(acked);
      return acked.length;
    } catch (_) {
      // Offline: keep the queue; report nothing flushed.
      return 0;
    }
  }
}
