import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import '../domain/nutrition.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';

const _epi = <(String, String, String)>[
  ('BCG', 'at birth', 'done'),
  ('OPV-0', 'at birth', 'done'),
  ('Penta-1', '6 wk', 'done'),
  ('PCV-1', '6 wk', 'done'),
  ('Penta-2', '10 wk', 'done'),
  ('Penta-3', '14 wk', 'due'),
  ('PCV-3', '14 wk', 'due'),
  ('IPV', '14 wk', 'due'),
  ('MR-1', '9 mo', 'due'),
  ('MR-2', '15 mo', 'upcoming'),
];

class ChildHealthPage extends StatefulWidget {
  const ChildHealthPage({super.key});

  @override
  State<ChildHealthPage> createState() => _ChildScreenState();
}

class _ChildScreenState extends State<ChildHealthPage> {
  late ChildAssessment _child;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final selected = context.read<AppState>().selected;
      _child = ChildAssessment(muac: selected?.muac ?? 11.2, weight: 6.9, length: 71);
      _init = true;
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Persist to PostgreSQL; the backend classifies the MUAC status and
      // returns the updated beneficiary, which refreshes the local cache.
      await state.recordChildAssessment(state.selectedId, _child);
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
    final muac = classifyMuac(_child.muac, _child.edema);

    return Column(
      children: [
        ScreenHeader(
          title: 'Child health & nutrition',
          subtitle: 'শিশু স্বাস্থ্য ও পুষ্টি · ${selected?.months ?? 9} months',
          onBack: () => state.go(AppScreen.profile, AppTab.cases),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: muac.bg,
                  border: Border.all(color: muac.color),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${muac.short} · ${muac.bn}',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: muac.color)),
                        Text('${_child.muac} cm',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: muac.color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(muac.label, style: const TextStyle(fontSize: 12, color: T.textSoft)),
                    const SizedBox(height: 6),
                    Text('→ ${muac.action}',
                        style: TextStyle(fontSize: 12, color: muac.color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SectionLabel('Anthropometry · পরিমাপ', margin: EdgeInsets.fromLTRB(0, 18, 0, 10)),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(TextSpan(children: [
                                  TextSpan(text: 'MUAC ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  TextSpan(text: 'mid-upper arm', style: TextStyle(fontSize: 11, color: T.textMuted)),
                                ])),
                                Text('বাহুর বেড়', style: TextStyle(fontSize: 11.5, color: T.text2)),
                              ],
                            ),
                          ),
                          _stepBtn(Icons.remove, () => setState(() {
                                _child.muac = double.parse((_child.muac - 0.1).clamp(0, 30).toStringAsFixed(1));
                              })),
                          SizedBox(
                            width: 64,
                            child: Text('${_child.muac}',
                                textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                          ),
                          _stepBtn(Icons.add, () => setState(() {
                                _child.muac = double.parse((_child.muac + 0.1).toStringAsFixed(1));
                              })),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: T.divider),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(
                        children: [
                          Expanded(child: _measure('Weight · ওজন', '${_child.weight} kg', T.text)),
                          Expanded(child: _measure('Length · দৈর্ঘ্য', '${_child.length} cm', T.text)),
                          Expanded(child: _measure('WAZ score', '−2.6', T.riskHigh)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: T.divider),
                    InkWell(
                      onTap: () => setState(() => _child.edema = !_child.edema),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _child.edema ? T.riskHigh : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: T.riskHigh, width: 1.5),
                              ),
                              child: _child.edema ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                            ),
                            const SizedBox(width: 11),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bilateral pitting oedema',
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                                  Text('দুই পায়ে শোথ — present = SAM',
                                      style: TextStyle(fontSize: 11, color: T.textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionLabel('Immunisation (EPI) · টিকা', margin: EdgeInsets.fromLTRB(0, 18, 0, 10)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final e in _epi) _epiChip(e)],
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'Save & refer if SAM · সংরক্ষণ', onPressed: _save),
            ],
          ),
        ),
      ],
    );
  }

  Widget _measure(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: T.text2)),
          Text(value, style: TextStyle(fontSize: 16, color: color)),
        ],
      );

  Widget _epiChip((String, String, String) e) {
    final (color, bg, mark, label) = switch (e.$3) {
      'done' => (const Color(0xFF03803D), const Color(0xFFE0EFEA), '✓', 'Done'),
      'due' => (const Color(0xFFC0492E), const Color(0xFFF7E4DE), '!', 'Due now'),
      _ => (const Color(0xFF9A958B), const Color(0xFFF1EEE7), '·', 'Upcoming'),
    };
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(mark, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 3),
          Text('$label · ${e.$2}', style: TextStyle(fontSize: 10, color: color)),
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
}
