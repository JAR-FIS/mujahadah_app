import 'package:flutter/material.dart';

import '../../../models/v2_custom_ibadah_draft.dart';
import '../../../models/v2_ibadah_catalog_item.dart';
import '../../../theme/v2_design_tokens.dart';

/// Screen S19 — Tambah Ibadah Kustom.
///
/// Implements the user interface for defining a custom daily worship template:
/// - Worship activity name input with real-time Indonesian validation.
/// - Category selector defaulting to [V2IbadahCategory.custom].
/// - Optional description / personal notes field.
/// - Strict business separation: does NOT contain target duration, start date,
///   or reminder settings (which belong exclusively to Program configuration S20).
/// - Fail-closed storage boundary: disabled or explanatory UI when save handler is null;
///   never reports fake saved templates or generates unpersisted IDs.
class V2CustomIbadahView extends StatefulWidget {
  final VoidCallback onBack;
  final CustomIbadahSaveCallback? onSave;
  final ValueChanged<V2IbadahCatalogItem>? onSaved;
  final ValueChanged<V2CustomIbadahDraft>? onDraftChanged;
  final V2CustomIbadahDraft? initialDraft;
  final V2IbadahCatalogItem? persistedItem;

  const V2CustomIbadahView({
    super.key,
    required this.onBack,
    this.onSave,
    this.onSaved,
    this.onDraftChanged,
    this.initialDraft,
    this.persistedItem,
  });

  @override
  State<V2CustomIbadahView> createState() => _V2CustomIbadahViewState();
}

class _V2CustomIbadahViewState extends State<V2CustomIbadahView> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late V2IbadahCategory _selectedCategory;

  String? _nameError;
  String? _saveErrorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialName = widget.persistedItem?.namaIbadah ??
        widget.initialDraft?.namaIbadah ??
        '';
    final initialDesc =
        widget.persistedItem?.deskripsi ?? widget.initialDraft?.deskripsi ?? '';
    _selectedCategory = widget.persistedItem?.category ??
        widget.initialDraft?.category ??
        V2IbadahCategory.custom;

    _nameController = TextEditingController(text: initialName);
    _descController = TextEditingController(text: initialDesc);

    _nameController.addListener(_notifyDraftChanged);
    _descController.addListener(_notifyDraftChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_notifyDraftChanged);
    _descController.removeListener(_notifyDraftChanged);
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _notifyDraftChanged() {
    widget.onDraftChanged?.call(_buildDraft());
  }

  V2CustomIbadahDraft _buildDraft() {
    return V2CustomIbadahDraft(
      namaIbadah: _nameController.text.trim(),
      category: _selectedCategory,
      deskripsi: _descController.text.trim(),
    );
  }

  void _validateForm() {
    final draft = _buildDraft();
    setState(() {
      _nameError = draft.validate();
      _saveErrorMessage = null;
    });
  }

  Future<void> _handleSave() async {
    // If this custom template has already been persisted to storage,
    // do not trigger a second save or generate duplicate records.
    if (widget.persistedItem != null) {
      widget.onSaved?.call(widget.persistedItem!);
      return;
    }

    _validateForm();
    if (_nameError != null) return;
    if (widget.onSave == null) return;

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      final draft = _buildDraft();
      final savedItem = await widget.onSave!(draft);

      if (!mounted) return;

      if (savedItem == null) {
        setState(() {
          _saveErrorMessage =
              'Gagal menyimpan ibadah kustom. Silakan coba lagi.';
          _isSaving = false;
        });
        return;
      }

      // Authoritative validation of saved item (FIX 4):
      final cleanId = savedItem.id.trim();
      final cleanName = savedItem.namaIbadah.trim();

      if (cleanId.isEmpty) {
        setState(() {
          _saveErrorMessage =
              'Identitas ibadah kustom tidak valid dari penyimpanan.';
          _isSaving = false;
        });
        return;
      }

      if (!savedItem.isCustom) {
        setState(() {
          _saveErrorMessage =
              'Ibadah kustom harus ditandai sebagai ibadah kustom.';
          _isSaving = false;
        });
        return;
      }

      if (!savedItem.isDailyEligible) {
        setState(() {
          _saveErrorMessage = savedItem.ineligibilityReason ??
              'Ibadah kustom harus memenuhi syarat target harian berturut-turut.';
          _isSaving = false;
        });
        return;
      }

      if (cleanName.isEmpty) {
        setState(() {
          _saveErrorMessage =
              'Nama ibadah kustom tidak boleh kosong dari penyimpanan.';
          _isSaving = false;
        });
        return;
      }

      // Valid saved item!
      widget.onSaved?.call(savedItem);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveErrorMessage = 'Terjadi kesalahan sistem saat menyimpan ibadah.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;
    final surfaceCard =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, isDark, textPrimary),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.lg,
                  vertical: V2Spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Persisted Item Info Banner (if previously saved)
                    if (widget.persistedItem != null) ...[
                      _buildPersistedBanner(
                          isDark, surfaceCard, borderColor, textSecondary),
                      const SizedBox(height: V2Spacing.lg),
                    ],

                    // Info Banner
                    _buildInfoBanner(
                        isDark, surfaceCard, borderColor, textSecondary),
                    const SizedBox(height: V2Spacing.lg),

                    // Name Input
                    _buildNameField(
                        isDark, surfaceCard, borderColor, textPrimary),
                    const SizedBox(height: V2Spacing.lg),

                    // Category Selector
                    _buildCategorySection(isDark, textPrimary, textSecondary),
                    const SizedBox(height: V2Spacing.lg),

                    // Description Input
                    _buildDescriptionField(isDark, surfaceCard, borderColor,
                        textPrimary, textSecondary),
                    const SizedBox(height: V2Spacing.lg),

                    // Save Error Alert (if any)
                    if (_saveErrorMessage != null)
                      _buildErrorBanner(isDark, _saveErrorMessage!),

                    const SizedBox(height: V2Spacing.xl),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            _buildBottomActionBar(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.md,
        vertical: V2Spacing.sm,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Kembali ke Katalog Program',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('v2_custom_ibadah_back_button'),
                icon: const Icon(Icons.arrow_back),
                color: textPrimary,
                onPressed: () {
                  widget.onDraftChanged?.call(_buildDraft());
                  widget.onBack();
                },
                tooltip: 'Kembali',
              ),
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              'Tambah Ibadah Kustom',
              style: V2Typography.headingLarge.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistedBanner(
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textSecondary,
  ) {
    final iconColor = isDark ? V2Colors.mint : V2Colors.deepTosca;
    return Container(
      key: const ValueKey('v2_custom_ibadah_persisted_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderMd,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: iconColor, size: 20),
          const SizedBox(width: V2Spacing.sm),
          Expanded(
            child: Text(
              'Ibadah kustom ini telah tersimpan di penyimpanan perangkat. Detail template dikunci untuk menjaga konsistensi amalan.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textSecondary,
  ) {
    final iconColor = isDark ? V2Colors.mint : V2Colors.deepTosca;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderMd,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: iconColor, size: 20),
          const SizedBox(width: V2Spacing.sm),
          Expanded(
            child: Text(
              'Ibadah kustom ini akan menjadi amalan harian berturut-turut. Durasi target dan pengingat waktu akan diatur pada langkah konfigurasi program.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textPrimary,
  ) {
    final isPersisted = widget.persistedItem != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nama Ibadah *',
          style: V2Typography.headingMedium.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        TextFormField(
          key: const ValueKey('v2_custom_ibadah_name_input'),
          controller: _nameController,
          readOnly: isPersisted,
          onChanged: (_) {
            if (_nameError != null) _validateForm();
          },
          style: TextStyle(color: textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Contoh: Sholat Tahajud 4 Rakaat, Dzikir Petang 100x',
            hintStyle: TextStyle(
              color: isDark ? V2Colors.darkTextMuted : V2Colors.lightTextMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: surfaceCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.md,
              vertical: V2Spacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: V2Radius.borderMd,
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: V2Radius.borderMd,
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: V2Radius.borderMd,
              borderSide: BorderSide(
                color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                width: 1.5,
              ),
            ),
            errorText: _nameError,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    const categories = [
      V2IbadahCategory.custom,
      V2IbadahCategory.sholatSunnah,
      V2IbadahCategory.dzikir,
      V2IbadahCategory.ibadahHarian,
      V2IbadahCategory.quran,
      V2IbadahCategory.maulid,
      V2IbadahCategory.puasa,
    ];

    final isPersisted = widget.persistedItem != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori Ibadah',
          style: V2Typography.headingMedium.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          'Pilih kategori amalan yang paling mendekati ibadahmu.',
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: V2Spacing.sm),
        Wrap(
          spacing: V2Spacing.xs,
          runSpacing: V2Spacing.xs,
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            final chipBg = isSelected
                ? (isDark
                    ? V2Colors.mint.withValues(alpha: 0.25)
                    : V2Colors.deepTosca.withValues(alpha: 0.15))
                : (isDark
                    ? V2Colors.darkSurfaceCard
                    : V2Colors.lightSurfaceCard);
            final chipBorder = isSelected
                ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                : (isDark ? V2Colors.darkBorder : V2Colors.lightBorder);
            final chipText = isSelected
                ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                : (isDark
                    ? V2Colors.darkTextSecondary
                    : V2Colors.lightTextSecondary);

            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ChoiceChip(
                key: ValueKey('v2_custom_ibadah_category_${cat.name}'),
                label: Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: chipText,
                  ),
                ),
                selected: isSelected,
                onSelected: isPersisted
                    ? null
                    : (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                          _notifyDraftChanged();
                        }
                      },
                backgroundColor: chipBg,
                selectedColor: chipBg,
                side: BorderSide(color: chipBorder),
                shape: const RoundedRectangleBorder(
                  borderRadius: V2Radius.borderFull,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isPersisted = widget.persistedItem != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deskripsi / Catatan (Opsional)',
          style: V2Typography.headingMedium.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        TextFormField(
          key: const ValueKey('v2_custom_ibadah_desc_input'),
          controller: _descController,
          readOnly: isPersisted,
          maxLines: 3,
          style: TextStyle(color: textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText:
                'Tuliskan catatan tata cara atau pengingat niat pribadi...',
            hintStyle: TextStyle(
              color: isDark ? V2Colors.darkTextMuted : V2Colors.lightTextMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: surfaceCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.md,
              vertical: V2Spacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: V2Radius.borderMd,
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: V2Radius.borderMd,
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: V2Radius.borderMd,
              borderSide: BorderSide(
                color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(bool isDark, String message) {
    return Container(
      key: const ValueKey('v2_custom_ibadah_error_banner'),
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? V2Colors.peach.withValues(alpha: 0.15)
            : V2Colors.peach.withValues(alpha: 0.25),
        borderRadius: V2Radius.borderMd,
        border: Border.all(
          color: isDark ? V2Colors.peach : Colors.brown,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: isDark ? V2Colors.peach : Colors.brown,
          ),
          const SizedBox(width: V2Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? V2Colors.peach : Colors.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, bool isDark) {
    final bottomBarBg = isDark ? V2Colors.darkSurface : V2Colors.lightSurface;
    final topBorderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    final isPersisted = widget.persistedItem != null;
    final hasSaveHandler = widget.onSave != null;
    final isActionEnabled =
        isPersisted ? !_isSaving : (hasSaveHandler && !_isSaving);

    return Container(
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: bottomBarBg,
        border: Border(
          top: BorderSide(color: topBorderColor, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasSaveHandler && !isPersisted)
              Padding(
                padding: const EdgeInsets.only(bottom: V2Spacing.sm),
                child: Text(
                  'Penyimpanan ibadah kustom akan segera tersedia.',
                  key: const ValueKey('v2_custom_ibadah_unavailable_notice'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? V2Colors.darkTextMuted
                        : V2Colors.lightTextMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 48,
                minWidth: double.infinity,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const ValueKey('v2_custom_ibadah_save_button'),
                  onPressed: isActionEnabled ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: V2Colors.warmGold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        isDark ? V2Colors.darkBorder : V2Colors.lightGray,
                    disabledForegroundColor: isDark
                        ? V2Colors.darkTextMuted
                        : V2Colors.lightTextMuted,
                    shape: const RoundedRectangleBorder(
                      borderRadius: V2Radius.borderFull,
                    ),
                    elevation: (isPersisted || hasSaveHandler) ? 2 : 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Lanjut ke Konfigurasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
