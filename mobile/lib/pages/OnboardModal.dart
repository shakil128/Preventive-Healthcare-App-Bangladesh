import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import '../domain/seed.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

/// Onboard a field officer: collect details, then generate + display the login
/// credentials the worker enters in the mobile app on first sign-in.
class OnboardModal extends StatefulWidget {
  const OnboardModal({super.key});

  @override
  State<OnboardModal> createState() => _OnboardModalState();
}

class _OnboardModalState extends State<OnboardModal> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _nid = TextEditingController();
  String _union = 'Char Bhola';
  WorkerRole _role = WorkerRole.fwa;
  bool _hasLoc = false;

  bool _done = false;
  bool _saving = false;
  String? _error;
  String _username = '';
  String _password = '';
  bool _copied = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _age.text.isNotEmpty &&
      _nid.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _phone.dispose();
    _nid.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      // The backend creates the account in PostgreSQL and returns the exact
      // credentials the officer signs in with — so the admin never sees a
      // password that differs from what is stored.
      final result = await state.onboardWorker(
        name: _name.text.trim(),
        age: int.tryParse(_age.text.trim()) ?? 0,
        phone: _phone.text.trim(),
        nid: _nid.text.trim(),
        union: _union,
        role: _role,
      );
      if (!mounted) return;
      setState(() {
        _username = result.username;
        _password = result.password;
        _done = true;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Could not reach the server. The account must be created online so '
            'the officer can sign in — check the backend and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: T.appBg,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            Flexible(child: SingleChildScrollView(child: _done ? _doneBody(context) : _formBody())),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: T.brand,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Onboard field officer',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('নতুন মাঠকর্মী যুক্ত করুন',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        ),
      );

  Widget _formBody() => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Full name · নাম'),
            _input(_name, 'e.g. Sahida Khatun'),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_label('Age · বয়স'), _input(_age, 'e.g. 28', number: true)],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_label('Phone · মোবাইল'), _input(_phone, '017XX-XXXXXX')],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _label('National ID (NID) · জাতীয় পরিচয়পত্র'),
            _input(_nid, '10 or 17 digit NID'),
            const SizedBox(height: 13),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _hasLoc = true),
                  icon: Icon(Icons.location_on, size: 14, color: _hasLoc ? Colors.white : T.brand),
                  label: Text('Use GPS', style: TextStyle(color: _hasLoc ? Colors.white : T.brand)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _hasLoc ? T.brand : Colors.white,
                    side: const BorderSide(color: T.brand),
                  ),
                ),
                const SizedBox(width: 9),
                if (_hasLoc)
                  const Text('✓ 22.3186° N, 90.9512° E',
                      style: TextStyle(fontSize: 12, color: T.brand, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 18),
            _label('Union'),
            _chipRow(kUnions, _union, (v) => setState(() => _union = v)),
            const SizedBox(height: 13),
            _label('Role · পদবি'),
            _chipRow(kRoles.map((r) => r.label).toList(), _role.label,
                (v) => setState(() => _role = WorkerRoleX.fromJson(v))),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_valid && !_saving) ? _generate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.brand,
                  disabledBackgroundColor: const Color(0xFF9DB8AF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create account & generate login →'),
              ),
            ),
            const SizedBox(height: 9),
            Center(
              child: Text(
                _error ??
                    (_valid
                        ? 'Username & password generated automatically'
                        : 'Fill name, age, NID and phone to continue'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    color: _error != null ? T.riskHigh : T.textMuted),
              ),
            ),
          ],
        ),
      );

  Widget _doneBody(BuildContext context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xFFE0EFEA), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: T.brand, size: 26),
                ),
                const SizedBox(height: 11),
                Text('${_name.text} added',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 3),
                const Text('Account created · share these credentials securely',
                    style: TextStyle(fontSize: 12.5, color: T.text2)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(color: T.brand, borderRadius: BorderRadius.circular(13)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('USERNAME',
                      style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
                  Text(_username,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  Divider(color: Colors.white.withOpacity(0.18), height: 28),
                  const Text('TEMPORARY PASSWORD',
                      style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
                  Text(_password,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              '⚠ The field officer enters these in the mobile app to log in. They will be asked to change the password on first sign-in.',
              style: TextStyle(fontSize: 12, color: T.text2),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'Username: $_username\nPassword: $_password'));
                      setState(() => _copied = true);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: T.border4),
                      foregroundColor: T.text,
                    ),
                    child: Text(_copied ? 'Copied ✓' : 'Copy credentials'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(t, style: const TextStyle(fontSize: 12, color: T.text2)),
      );

  Widget _input(TextEditingController c, String hint, {bool number = false}) => TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: T.border4)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: T.border4)),
        ),
      );

  Widget _chipRow(List<String> options, String value, ValueChanged<String> onChange) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChange(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: value == o ? T.brand : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: value == o ? T.brand : T.border4),
                ),
                child: Text(o,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: value == o ? Colors.white : const Color(0xFF5C594F))),
              ),
            ),
        ],
      );
}
