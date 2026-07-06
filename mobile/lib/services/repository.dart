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

  Future<List<Beneficiary>> beneficiaries() => _db.beneficiaries();
  Future<Beneficiary?> beneficiary(String id) => _db.beneficiary(id);
  Future<List<Worker>> workers() => _db.workers();
  Future<int> pendingCount() => _db.pendingCount();

  Future<void> addBeneficiary(Beneficiary b) async {
    await _db.putBeneficiary(b);
    await _db.enqueue('registration', b.id, 'Registered ${b.name}');
  }

  /// Record an ANC visit outcome against a beneficiary (risk + next visit).
  Future<void> recordAncVisit(
    String id, {
    required RiskLevel risk,
    String? reason,
    required String next,
  }) async {
    final b = await _db.beneficiary(id);
    if (b == null) return;
    final updated = b.copyWith(
      risk: risk,
      reason: reason,
      next: next,
      anc: b.anc == null ? null : b.anc! + 1,
    );
    await _db.putBeneficiary(updated);
    await _db.enqueue('visit', id, 'ANC visit for ${b.name}');
  }

  Future<void> recordChildAssessment(
    String id,
    ChildAssessment assessment, {
    required RiskLevel risk,
    String? reason,
  }) async {
    final b = await _db.beneficiary(id);
    if (b == null) return;
    final updated = b.copyWith(risk: risk, reason: reason, muac: assessment.muac);
    await _db.putBeneficiary(updated);
    await _db.enqueue('child-assessment', id, 'Child assessment for ${b.name} (MUAC ${assessment.muac})');
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
