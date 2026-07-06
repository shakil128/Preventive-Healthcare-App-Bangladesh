import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import '../domain/risk.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';

const _dangerDefs = <(String, String, String)>[
  ('bleeding', 'Vaginal bleeding', 'যোনিপথে রক্তক্ষরণ'),
  ('headache', 'Severe headache', 'তীব্র মাথাব্যথা'),
  ('blurred', 'Blurred vision', 'ঝাপসা দৃষ্টি'),
  ('swelling', 'Swelling face / hands', 'হাত-মুখ ফোলা'),
  ('convulsions', 'Convulsions', 'খিঁচুনি'),
  ('fever', 'High fever', 'অতিরিক্ত জ্বর'),
  ('fetal', 'Reduced fetal movement', 'নড়াচড়া কম'),
  ('abdo', 'Severe abdominal pain', 'তীব্র পেটব্যথা'),
  ('breathing', 'Difficult breathing', 'শ্বাসকষ্ট'),
];

const _serviceDefs = <(String, String, String)>[
  ('ifa', 'IFA tablets given', 'আয়রন-ফলিক ট্যাবলেট'),
  ('tt', 'TT / Td up to date', 'টিটি টিকা'),
  ('calcium', 'Calcium given', 'ক্যালসিয়াম'),
];

class AncVisitPage extends StatefulWidget {
  const AncVisitPage({super.key});

  @override
  State<AncVisitPage> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<AncVisitPage> {
  final _v = AncVisit(
    sbp: 150,
    dbp: 95,
    weight: 58,
    hb: 9.5,
    fundal: 32,
    fhr: 142,
    danger: DangerSigns(headache: true, swelling: true),
  );
  final _services = AncServices(ifa: true, tt: true, calcium: false);
  bool _dangerOpen = false;

  bool _dangerOf(String key) {
    final d = _v.danger;
    return switch (key) {
      'headache' => d.headache,
      'blurred' => d.blurred,
      'swelling' => d.swelling,
      'bleeding' => d.bleeding,
      'convulsions' => d.convulsions,
      'fever' => d.fever,
      'fetal' => d.fetal,
      'abdo' => d.abdo,
      'breathing' => d.breathing,
      _ => false,
    };
  }

  void _toggleDanger(String key) {
    final d = _v.danger;
    setState(() {
      switch (key) {
        case 'headache':
          d.headache = !d.headache;
        case 'blurred':
          d.blurred = !d.blurred;
        case 'swelling':
          d.swelling = !d.swelling;
        case 'bleeding':
          d.bleeding = !d.bleeding;
        case 'convulsions':
          d.convulsions = !d.convulsions;
        case 'fever':
          d.fever = !d.fever;
        case 'fetal':
          d.fetal = !d.fetal;
        case 'abdo':
          d.abdo = !d.abdo;
        case 'breathing':
          d.breathing = !d.breathing;
      }
    });
  }

  bool _serviceOf(String key) => switch (key) {
        'ifa' => _services.ifa,
        'tt' => _services.tt,
        'calcium' => _services.calcium,
        _ => false,
      };

  void _toggleService(String key) {
    setState(() {
      switch (key) {
        case 'ifa':
          _services.ifa = !_services.ifa;
        case 'tt':
          _services.tt = !_services.tt;
        case 'calcium':
          _services.calcium = !_services.calcium;
      }
    });
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Persist to PostgreSQL; the backend classifies risk and returns the
      // updated beneficiary, which refreshes the local cache.
      await state.recordAncVisit(state.selectedId, _v);
      if (!mounted) return;
      state.go(AppScreen.profile, AppTab.cases);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Could not save to server · সার্ভারে সংরক্ষণ ব্যর্থ — সংযোগ দেখে আবার চেষ্টা করুন'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selected;
    final risk = computeAncRisk(_v);
    final activeDanger = _dangerDefs.where((d) => _dangerOf(d.$1)).toList();
    final dangerSummary = activeDanger.isNotEmpty
        ? '${activeDanger.length} selected · ${activeDanger.map((d) => d.$2).join(', ')}'
        : 'Select danger signs · বিপদ চিহ্ন নির্বাচন করুন';

    return Column(
      children: [
        ScreenHeader(
          title: 'ANC visit · ${selected?.name ?? ''}',
          subtitle: 'গর্ভকালীন পরিদর্শন · ${selected?.weeks ?? '—'} weeks',
          onBack: () => state.go(AppScreen.home, AppTab.home),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _riskBanner(risk),
              const SectionLabel('Vitals · শারীরিক পরিমাপ', margin: EdgeInsets.fromLTRB(0, 18, 0, 10)),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _vitalRow('Systolic BP', 'রক্তচাপ (উপরের)', _v.sbp.toString(),
                        () => setState(() => _v.sbp -= 5), () => setState(() => _v.sbp += 5)),
                    _divider(),
                    _vitalRow('Diastolic BP', 'রক্তচাপ (নিচের)', _v.dbp.toString(),
                        () => setState(() => _v.dbp -= 5), () => setState(() => _v.dbp += 5)),
                    _divider(),
                    _vitalRow('Haemoglobin', 'হিমোগ্লোবিন', _v.hb.toString(),
                        () => setState(() => _v.hb = (_v.hb - 0.5).clamp(0, 30).toDouble()),
                        () => setState(() => _v.hb = _v.hb + 0.5),
                        suffix: ' g/dL'),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(child: _miniStat('Weight · ওজন', '${_v.weight} kg')),
                  const SizedBox(width: 11),
                  Expanded(child: _miniStat('Fundal · ফান্ডাল', '${_v.fundal} cm')),
                  const SizedBox(width: 11),
                  Expanded(child: _miniStat('Fetal HR', '${_v.fhr}')),
                ],
              ),
              const SectionLabel('Danger signs · বিপদ চিহ্ন (select all present)',
                  color: T.riskHigh, margin: EdgeInsets.fromLTRB(0, 18, 0, 10)),
              _dangerSelector(dangerSummary, activeDanger.isNotEmpty),
              const SectionLabel('WHO ANC services · প্রদত্ত সেবা',
                  margin: EdgeInsets.fromLTRB(0, 18, 0, 10)),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _serviceDefs.length; i++) ...[
                      _serviceRow(_serviceDefs[i]),
                      if (i < _serviceDefs.length - 1) _divider(),
                    ],
                  ],
                ),
              ),
              if (risk.level == RiskLevel.high) _referralCard(),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Save visit · সংরক্ষণ', onPressed: _save),
              const SizedBox(height: 9),
              const Center(
                child: Text('Next visit auto-scheduled · 13 Jul 2026',
                    style: TextStyle(fontSize: 11.5, color: T.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _riskBanner(ComputedRisk risk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: risk.bg,
        border: Border.all(color: risk.color),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 11, height: 11, decoration: BoxDecoration(color: risk.color, shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Text('${risk.label} · ${risk.bn}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: risk.color)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text('Auto-calculated from vitals & danger signs · স্বয়ংক্রিয় ঝুঁকি নির্ণয়',
                style: TextStyle(fontSize: 11.5, color: T.textSoft)),
          ),
          for (final r in risk.reasons)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('▸ ', style: TextStyle(color: risk.color)),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 12.5, color: T.textSoft))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _vitalRow(String en, String bn, String value, VoidCallback onMinus, VoidCallback onPlus,
      {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: en, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (suffix.isNotEmpty)
                    TextSpan(text: suffix, style: const TextStyle(fontSize: 11, color: T.textMuted)),
                ])),
                Text(bn, style: const TextStyle(fontSize: 11.5, color: T.text2)),
              ],
            ),
          ),
          _stepBtn(Icons.remove, onMinus),
          SizedBox(
            width: 60,
            child: Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ),
          _stepBtn(Icons.add, onPlus),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: T.appBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: T.border4),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF5C594F)),
        ),
      );

  Widget _miniStat(String label, String value) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: T.text2)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16)),
          ],
        ),
      );

  Widget _dangerSelector(String summary, bool active) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() => _dangerOpen = !_dangerOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: active ? T.riskHigh : const Color(0xFFE5E1D8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(summary,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: active ? T.riskHigh : T.textMuted)),
                ),
                Icon(_dangerOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: T.textMuted),
              ],
            ),
          ),
        ),
        if (_dangerOpen)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E1D8)),
            ),
            child: Column(
              children: [
                for (final d in _dangerDefs) _dangerRow(d),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dangerRow((String, String, String) d) {
    final on = _dangerOf(d.$1);
    return InkWell(
      onTap: () => _toggleDanger(d.$1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFFBEEE9) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF3F0E9))),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? T.riskHigh : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: on ? T.riskHigh : const Color(0xFFCFCABF), width: 1.5),
              ),
              child: on ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.$2,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: on ? T.riskHigh : T.textSoft)),
                  Text(d.$3, style: const TextStyle(fontSize: 11, color: T.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceRow((String, String, String) s) {
    final on = _serviceOf(s.$1);
    return InkWell(
      onTap: () => _toggleService(s.$1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? T.brand : const Color(0xFFCFCABF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.check, size: 13, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.$2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  Text(s.$3, style: const TextStyle(fontSize: 11, color: T.textMuted)),
                ],
              ),
            ),
            Text(on ? 'Given' : 'Pending',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: on ? T.brand : T.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _referralCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: T.riskHigh, borderRadius: BorderRadius.circular(13)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠ Refer to facility · জরুরি রেফার',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 3),
          Text(
            'High-risk vitals detected. Arrange referral to the nearest Upazila Health Complex and inform the supervisor.',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: T.riskHigh,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              child: const Text('Generate referral slip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 1, color: T.divider);
}
