import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../../services/visitor_service.dart';

/// Screen where a NEW visitor is registered.
class AddVisitorScreen extends StatefulWidget {
  const AddVisitorScreen({super.key});

  @override
  State<AddVisitorScreen> createState() => _AddVisitorScreenState();
}

class _AddVisitorScreenState extends State<AddVisitorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _service = VisitorService();

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.addVisitor(
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        company: _addressCtrl.text,
        purpose: _purposeCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(title: const Text('New entry')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- Welcoming header --------------------------------------
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient(brightness),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.seed.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register a visitor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Fill in the details below to record the entry.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Fields -------------------------------------------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Visitor name *',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Address (optional)',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _purposeCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Purpose of visit (optional)',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneCtrl,
                          obscureText: true,
                          obscuringCharacter: '•',
                          keyboardType: TextInputType.phone,
                          enableSuggestions: false,
                          autocorrect: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+ ]')),
                            LengthLimitingTextInputFormatter(15),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.isEmpty) return null; // optional
                            if (digits.length < 7) {
                              return 'Number looks too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        // ---- Polite remark under the phone field -----------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please hand the device to the visitor or '
                                'client so they can enter their own number.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_saving ? 'Saving…' : 'Record entry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
