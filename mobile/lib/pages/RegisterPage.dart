import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';

/// Multi-field registration capturing personal, location (GPS) & pregnancy data.
/// Fields are pre-filled to match the design reference; saving persists the new
/// beneficiary to PostgreSQL and advances to the first ANC visit.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterPage> {
  final _name = TextEditingController(text: 'Rahima Begum');
  final _age = TextEditingController(text: '19');
  final _mobile = TextEditingController(text: '');
  final _nid = TextEditingController(text: '1990 4521 8847');
  final _village = TextEditingController(text: 'Char Bhola');
  final _union = TextEditingController(text: 'Char Bhola');
  final _lmp = TextEditingController(text: '05 Jan 2026');
  final _gravida = TextEditingController(text: '2');
  final _para = TextEditingController(text: '1');
  final _blood = TextEditingController(text: 'B+');

  String _gps = '22.318° N, 90.951° E';
  bool _capturing = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _age, _mobile, _nid, _village, _union, _lmp, _gravida, _para, _blood]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final beneficiary = Beneficiary(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      bn: '',
      type: BeneficiaryType.anc,
      village: _village.text.trim(),
      code: 'ANC-${DateTime.now().millisecondsSinceEpoch % 10000}',
      risk: RiskLevel.low,
      next: 'Due today',
      age: int.tryParse(_age.text.trim()),
      weeks: 0,
      anc: 0,
      edd: '12 Aug 2026',
    );
    try {
      await state.addBeneficiary(beneficiary);
      if (!mounted) return;
      // Attach the first ANC visit to the beneficiary we just created.
      state.selectedId = beneficiary.id;
      state.go(AppScreen.visit, AppTab.add);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Could not save to server · সার্ভারে সংরক্ষণ ব্যর্থ — সংযোগ দেখে আবার চেষ্টা করুন'),
      ));
    }
  }

  void _captureGps() {
    setState(() => _capturing = true);
    // A real device would read GPS; we simulate a capture for the prototype.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _gps = '22.318° N, 90.951° E';
        _capturing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      children: [
        ScreenHeader(
          title: 'New registration',
          subtitle: 'নতুন নিবন্ধন',
          onBack: () => state.go(AppScreen.home, AppTab.home),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Step 1 / 3', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionLabel('Personal · ব্যক্তিগত তথ্য'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _field('Full name · নাম', _name),
                    Row(
                      children: [
                        Expanded(child: _field('Age · বয়স', _age)),
                        const SizedBox(width: 14),
                        Expanded(
                            flex: 2,
                            child: _field('Mobile · মোবাইল', _mobile,
                                hint: '017XX-XXXXXX')),
                      ],
                    ),
                    _field('NID / Birth reg. no.', _nid, last: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Location · অবস্থান'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _field('Village · গ্রাম', _village)),
                        const SizedBox(width: 14),
                        Expanded(child: _field('Union', _union)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GPS location', style: TextStyle(fontSize: 11.5, color: T.text2)),
                                const SizedBox(height: 3),
                                Text(_gps, style: const TextStyle(fontSize: 12.5)),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _captureGps,
                            icon: const Icon(Icons.location_on, size: 14, color: T.brand),
                            label: Text(_capturing ? 'Capturing…' : 'Captured',
                                style: const TextStyle(fontSize: 11.5, color: T.brand, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Pregnancy · গর্ভকাল'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _field('LMP · শেষ মাসিক', _lmp)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 11),
                                child: Text('EDD (auto)', style: TextStyle(fontSize: 11.5, color: T.brand)),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 3, bottom: 11),
                                child: Text('12 Aug 2026',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _field('Gravida', _gravida, last: true)),
                        const SizedBox(width: 14),
                        Expanded(child: _field('Para', _para, last: true)),
                        const SizedBox(width: 14),
                        Expanded(child: _field('Blood grp', _blood, last: true)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: _saving
                    ? 'Saving…'
                    : 'Save & start first ANC visit →',
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 9),
              const Center(
                child: Text('Saved to the central register (PostgreSQL)',
                    style: TextStyle(fontSize: 11.5, color: T.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool last = false, String? hint}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: T.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: T.text2)),
          const SizedBox(height: 3),
          TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 14.5, color: T.text),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
