import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
  final _otherPurposeCtrl = TextEditingController();
  final _service = VisitorService();
  final ImagePicker _picker = ImagePicker();

  /// Selectable purposes shown in the dropdown. Keep "Others" last so the
  /// custom text field naturally appears at the bottom when chosen.
  static const List<String> _purposeOptions = <String>[
    'Official',
    'Meeting',
    'Query / Enquiry',
    'Vendors',
    'Interview',
    'Personal',
    'Others',
  ];

  String? _selectedPurpose;

  /// Captured photo bytes (already downscaled + compressed by the picker).
  /// Kept in memory only until the entry is saved.
  Uint8List? _photoBytes;

  bool _saving = false;

  bool get _isOther => _selectedPurpose == 'Others';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _otherPurposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Upload the photo first (if any); the RPC only needs its object key.
      String? photoPath;
      if (_photoBytes != null) {
        photoPath = await _service.uploadVisitorPhoto(_photoBytes!);
      }
      // For "Others" use the typed-in text; otherwise use the chosen option.
      final purpose =
          _isOther ? _otherPurposeCtrl.text.trim() : (_selectedPurpose ?? '');
      await _service.addVisitor(
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        company: _addressCtrl.text,
        purpose: purpose,
        photoPath: photoPath,
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

  /// Capture/select a photo. The picker downsizes to at most 720px and
  /// compresses to ~55% JPEG *before* handing us the bytes, so the file stays
  /// small (typically well under 100 KB) — light to upload and to render on
  /// older devices.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 55,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get photo: $e')),
      );
    }
  }

  void _choosePhotoSource() {
    if (_saving) return;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.photo_camera_rounded, color: scheme.primary),
              ),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.photo_library_rounded, color: scheme.primary),
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoBytes != null)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.error.withValues(alpha: 0.12),
                  child: Icon(Icons.delete_outline_rounded, color: scheme.error),
                ),
                title: Text('Remove photo',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photoBytes = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// A tappable, circular photo well: shows the captured photo (with a small
  /// edit badge) or a camera placeholder. Kept compact and simple so it stays
  /// smooth on older devices.
  Widget _buildPhotoPicker(ColorScheme scheme) {
    const double d = 104;
    final hasPhoto = _photoBytes != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _choosePhotoSource,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: hasPhoto ? 0 : 0.4),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasPhoto
                    ? Image.memory(
                        _photoBytes!,
                        width: d,
                        height: d,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: scheme.primary, size: 30),
                          const SizedBox(height: 6),
                          Text(
                            'Add photo',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              if (hasPhoto)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                    child: Icon(Icons.edit_rounded,
                        color: scheme.onPrimary, size: 15),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasPhoto ? 'Tap to change or remove' : 'Visitor photo (optional)',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                // ---- Subtle, professional header ---------------------------
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.person_add_alt_1_rounded,
                            color: scheme.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register a visitor',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Fill in the details below to record the entry.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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
                        // ---- Optional visitor photo ------------------------
                        Center(child: _buildPhotoPicker(scheme)),
                        const SizedBox(height: 20),
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
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPurpose,
                          isExpanded: true,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radius),
                          decoration: const InputDecoration(
                            labelText: 'Purpose of visit (optional)',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                          items: [
                            for (final option in _purposeOptions)
                              DropdownMenuItem<String>(
                                value: option,
                                child: Text(option),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) =>
                                  setState(() => _selectedPurpose = value),
                        ),
                        // ---- Free-text reason, only when "Others" is picked --
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: _isOther
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: TextFormField(
                                    controller: _otherPurposeCtrl,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Please specify the purpose',
                                      prefixIcon:
                                          Icon(Icons.edit_note_outlined),
                                    ),
                                    validator: (v) {
                                      if (!_isOther) return null;
                                      return (v == null || v.trim().isEmpty)
                                          ? 'Please describe the purpose'
                                          : null;
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneCtrl,
                          obscureText: true,
                          obscuringCharacter: '•',
                          keyboardType: TextInputType.number,
                          enableSuggestions: false,
                          autocorrect: false,
                          inputFormatters: [
                            // Digits only — no '+', spaces or symbols.
                            FilteringTextInputFormatter.digitsOnly,
                            // Never allow more than 10 digits.
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            hintText: '10-digit mobile number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.isEmpty) return null; // optional
                            if (digits.length != 10) {
                              return 'Enter a valid 10-digit number';
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
