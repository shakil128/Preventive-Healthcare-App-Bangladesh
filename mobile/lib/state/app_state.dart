/// UI / session state. Domain data lives in the offline store (sqflite via the
/// repository); this notifier holds navigation + auth + connectivity flags and a
/// cached view of the data that screens render from.
import 'package:flutter/material.dart';

import '../services/repository.dart';
import '../domain/models.dart';

enum AppView { app, portal }

enum AppScreen { home, list, register, visit, child, profile }

enum AppTab { home, cases, add, alerts }

enum PortalSection { dashboard, beneficiaries, indicators, workers }

enum ListFilter { all, anc, pnc, child, adolescent, elderly, disabled, pregnant, high }

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class AppState extends ChangeNotifier {
  AppState(this.repo);

  final Repository repo;

  AppView view = AppView.app;

  // mobile app
  bool loggedIn = false;
  AppScreen screen = AppScreen.home;
  AppTab tab = AppTab.home;
  ListFilter listFilter = ListFilter.all;
  String selectedId = 'b1';
  String profileTab = 'overview';

  // portal
  bool adminLoggedIn = false;
  PortalSection portalSection = PortalSection.dashboard;

  // connectivity / sync (offline-first)
  bool online = true;
  String lastSynced = '2 days ago · 14:20';
  bool syncing = false;

  // cached data
  List<Beneficiary> beneficiaries = [];
  List<Worker> workers = [];
  int pending = 0;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    beneficiaries = await repo.beneficiaries();
    workers = await repo.workers();
    pending = await repo.pendingCount();
    notifyListeners();
  }

  Beneficiary? get selected {
    for (final b in beneficiaries) {
      if (b.id == selectedId) return b;
    }
    return null;
  }

  void setView(AppView v) {
    view = v;
    notifyListeners();
  }

  // ---- field app navigation ----

  void appLogin() {
    loggedIn = true;
    screen = AppScreen.home;
    tab = AppTab.home;
    notifyListeners();
  }

  void appLogout() {
    loggedIn = false;
    notifyListeners();
  }

  void go(AppScreen s, [AppTab? t]) {
    screen = s;
    if (t != null) tab = t;
    notifyListeners();
  }

  void openProfile(String id) {
    selectedId = id;
    screen = AppScreen.profile;
    tab = AppTab.cases;
    notifyListeners();
  }

  void setFilter(ListFilter f) {
    listFilter = f;
    screen = AppScreen.list;
    tab = f == ListFilter.high ? AppTab.alerts : AppTab.cases;
    notifyListeners();
  }

  void setProfileTab(String t) {
    profileTab = t;
    notifyListeners();
  }

  // ---- portal navigation ----

  void adminLogin() {
    adminLoggedIn = true;
    portalSection = PortalSection.dashboard;
    notifyListeners();
  }

  void adminLogout() {
    adminLoggedIn = false;
    notifyListeners();
  }

  void setSection(PortalSection s) {
    portalSection = s;
    notifyListeners();
  }

  void setOnline(bool v) {
    online = v;
    notifyListeners();
  }

  // ---- writes (delegate to repo, then refresh cache) ----

  Future<void> recordAncVisit(String id,
      {required RiskLevel risk, String? reason, required String next}) async {
    await repo.recordAncVisit(id, risk: risk, reason: reason, next: next);
    await refresh();
  }

  Future<void> recordChildAssessment(String id, ChildAssessment a,
      {required RiskLevel risk, String? reason}) async {
    await repo.recordChildAssessment(id, a, risk: risk, reason: reason);
    await refresh();
  }

  Future<void> addWorker(Worker w) async {
    await repo.addWorker(w);
    await refresh();
  }

  /// Onboard a field officer via the backend: persists the account in
  /// PostgreSQL and returns the credentials the officer uses to sign in.
  Future<({Worker worker, String username, String password})> onboardWorker({
    required String name,
    required int age,
    required String phone,
    required String nid,
    required String union,
    required WorkerRole role,
  }) async {
    final result = await repo.onboardWorker(
      name: name, age: age, phone: phone, nid: nid, union: union, role: role);
    await refresh();
    return result;
  }

  Future<void> sync() async {
    if (syncing || pending == 0) return;
    syncing = true;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await repo.flushSyncQueue();
      lastSynced = 'just now · ${_hhmm(DateTime.now())}';
      await refresh();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}

/// Helper used by list/portal filters.
List<Beneficiary> filterBeneficiaries(List<Beneficiary> items, ListFilter filter) {
  switch (filter) {
    case ListFilter.all:
      return items;
    case ListFilter.pregnant:
      return items
          .where((b) => b.type == BeneficiaryType.anc || b.type == BeneficiaryType.pnc)
          .toList();
    case ListFilter.high:
      return items.where((b) => b.risk == RiskLevel.high).toList();
    case ListFilter.anc:
      return items.where((b) => b.type == BeneficiaryType.anc).toList();
    case ListFilter.pnc:
      return items.where((b) => b.type == BeneficiaryType.pnc).toList();
    case ListFilter.child:
      return items.where((b) => b.type == BeneficiaryType.child).toList();
    case ListFilter.adolescent:
      return items.where((b) => b.type == BeneficiaryType.adolescent).toList();
    case ListFilter.elderly:
      return items.where((b) => b.type == BeneficiaryType.elderly).toList();
    case ListFilter.disabled:
      return items.where((b) => b.type == BeneficiaryType.disabled).toList();
  }
}
