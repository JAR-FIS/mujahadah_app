import 'package:flutter/material.dart';

import '../../../core/date/date_service.dart';
import '../../../models/v2_ibadah_catalog_item.dart';
import '../../../models/v2_program_config_draft.dart';
import '../../../services/program_v2_creation_service.dart';
import '../../../theme/v2_design_tokens.dart';

/// Screen S20 — Konfigurasi Program.
///
/// Implements the configuration step for new Mujahadah programs:
/// - Target Duration: Preset milestones (40, 60, 90, 100 days) or Custom (40..365 days).
/// - Operational Start Day: "Hari Ini" vs "Besok" resolved against DateService 03:00 boundary.
/// - Reminder: Optional toggle with strict 24h `HH:mm` format selection.
/// - Mandatory downstream navigation: Proceeds strictly to Review Program.
class V2ProgramConfigView extends StatefulWidget {
  final V2IbadahCatalogItem item;
  final V2ProgramConfigDraft initialDraft;
  final DateService? dateService;
  final VoidCallback onBack;
  final ValueChanged<V2ProgramConfigDraft> onProceedToReview;

  const V2ProgramConfigView({
    super.key,
    required this.item,
    required this.initialDraft,
    this.dateService,
    required this.onBack,
    required this.onProceedToReview,
  });

  @override
  State<V2ProgramConfigView> createState() => _V2ProgramConfigViewState();
}

class _V2ProgramConfigViewState extends State<V2ProgramConfigView> {
  late final DateService _dateService;
  late int _selectedTargetDays;
  late bool _isCustomDuration;
  late final TextEditingController _customDurationController;
  late ProgramStartSelection _selectedStartSelection;
  late bool _isReminderEnabled;
  late TimeOfDay _reminderTime;

  String? _durationError;
  String? _reminderError;

  @override
  void initState() {
    super.initState();
    _dateService = widget.dateService ?? DateService();

    final draft = widget.initialDraft;
    _selectedTargetDays = draft.targetDays;
    _isCustomDuration = draft.isCustomDuration;
    _customDurationController = TextEditingController(
      text: draft.customDurationText,
    );
    _selectedStartSelection = draft.startSelection;
    _isReminderEnabled = draft.isReminderEnabled;

    if (draft.reminderTime != null &&
        V2ProgramConfigDraft.reminderTimeRegex.hasMatch(draft.reminderTime!)) {
      final parts = draft.reminderTime!.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      _reminderTime = const TimeOfDay(hour: 5, minute: 0);
    }

    _validateForm();
  }

  @override
  void dispose() {
    _customDurationController.dispose();
    super.dispose();
  }

  String get _formattedReminderTime {
    final h = _reminderTime.hour.toString().padLeft(2, '0');
    final m = _reminderTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  V2ProgramConfigDraft _buildDraft({String? reviewedStartDayKey}) {
    return V2ProgramConfigDraft(
      targetDays: _selectedTargetDays,
      isCustomDuration: _isCustomDuration,
      customDurationText: _customDurationController.text.trim(),
      startSelection: _selectedStartSelection,
      isReminderEnabled: _isReminderEnabled,
      reminderTime: _isReminderEnabled ? _formattedReminderTime : null,
      reviewedStartDayKey:
          reviewedStartDayKey ?? widget.initialDraft.reviewedStartDayKey,
      restartedFromProgramId: widget.initialDraft.restartedFromProgramId,
    );
  }

  void _validateForm() {
    final draft = _buildDraft();
    setState(() {
      _durationError = draft.validateDuration();
      _reminderError = draft.validateReminder();
    });
  }

  String _formatDayKeyIndonesian(String dayKey) {
    try {
      final dt = DateService.parseDayKey(dayKey);
      const months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dayKey;
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
      _validateForm();
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

    final currentInstant = _dateService.now;
    final isPreBoundary =
        currentInstant.hour < DateService.operationalBoundaryHour;
    final todayKey = _dateService.getTodayDayKey();
    final tomorrowKey = _dateService.getNextDayKey(todayKey);

    final isValid = _durationError == null && _reminderError == null;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, isDark, textPrimary),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.lg,
                  vertical: V2Spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    _buildHeaderCard(context, isDark, surfaceCard, borderColor,
                        textPrimary, textSecondary),
                    const SizedBox(height: V2Spacing.lg),

                    // Target Duration Section
                    _buildDurationSection(isDark, surfaceCard, borderColor,
                        textPrimary, textSecondary),
                    const SizedBox(height: V2Spacing.lg),

                    // Start Date Section
                    _buildStartSelectionSection(
                      isDark: isDark,
                      surfaceCard: surfaceCard,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      todayKey: todayKey,
                      tomorrowKey: tomorrowKey,
                      isPreBoundary: isPreBoundary,
                    ),
                    const SizedBox(height: V2Spacing.lg),

                    // Reminder Section
                    _buildReminderSection(
                      context: context,
                      isDark: isDark,
                      surfaceCard: surfaceCard,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: V2Spacing.xl),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            _buildBottomActionBar(context, isDark, isValid),
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
            label: 'Kembali',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('v2_program_config_back_button'),
                icon: const Icon(Icons.arrow_back),
                color: textPrimary,
                onPressed: widget.onBack,
                tooltip: 'Kembali',
              ),
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              'Konfigurasi Program',
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

  Widget _buildHeaderCard(
    BuildContext context,
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final catBg = isDark
        ? V2Colors.mint.withValues(alpha: 0.15)
        : V2Colors.deepTosca.withValues(alpha: 0.1);
    final catText = isDark ? V2Colors.mint : V2Colors.deepTosca;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: borderColor),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: V2Spacing.sm,
            runSpacing: V2Spacing.xs,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.md,
                  vertical: V2Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: catBg,
                  borderRadius: V2Radius.borderFull,
                ),
                child: Text(
                  widget.item.category.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: catText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.md,
                  vertical: V2Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? V2Colors.darkSurfaceElevated
                      : V2Colors.lightGray,
                  borderRadius: V2Radius.borderFull,
                ),
                child: Text(
                  'Min. ${widget.item.defaultTargetDays} hari',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? V2Colors.peach : V2Colors.warmGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Spacing.md),
          Text(
            widget.item.namaIbadah,
            style: V2Typography.headingLarge.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSection(
    bool isDark,
    Color surfaceCard,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Durasi Istiqomah',
          style: V2Typography.headingMedium.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          'Pilih milestone istiqomah atau tentukan target durasi kustom (40 - 365 hari).',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: V2Spacing.md),

        // Presets + Kustom Choice Chips
        Wrap(
          spacing: V2Spacing.sm,
          runSpacing: V2Spacing.sm,
          children: [
            ...V2ProgramConfigDraft.presetDurations.map((days) {
              final isSelected =
                  !_isCustomDuration && _selectedTargetDays == days;
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ChoiceChip(
                  key: ValueKey('v2_config_preset_$days'),
                  label: Text('$days Hari'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isCustomDuration = false;
                        _selectedTargetDays = days;
                      });
                      _validateForm();
                    }
                  },
                  selectedColor: isDark
                      ? V2Colors.mint.withValues(alpha: 0.25)
                      : V2Colors.deepTosca.withValues(alpha: 0.15),
                  backgroundColor: isDark
                      ? V2Colors.darkSurfaceCard
                      : V2Colors.lightSurfaceCard,
                  side: BorderSide(
                    color: isSelected
                        ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                        : (isDark ? V2Colors.darkBorder : V2Colors.lightBorder),
                  ),
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                        : (isDark
                            ? V2Colors.darkTextPrimary
                            : V2Colors.lightTextPrimary),
                  ),
                ),
              );
            }),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ChoiceChip(
                key: const ValueKey('v2_config_preset_custom'),
                label: const Text('Kustom'),
                selected: _isCustomDuration,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isCustomDuration = true;
                    });
                    _validateForm();
                  }
                },
                selectedColor: isDark
                    ? V2Colors.mint.withValues(alpha: 0.25)
                    : V2Colors.deepTosca.withValues(alpha: 0.15),
                backgroundColor: isDark
                    ? V2Colors.darkSurfaceCard
                    : V2Colors.lightSurfaceCard,
                side: BorderSide(
                  color: _isCustomDuration
                      ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                      : (isDark ? V2Colors.darkBorder : V2Colors.lightBorder),
                ),
                labelStyle: TextStyle(
                  fontWeight:
                      _isCustomDuration ? FontWeight.w700 : FontWeight.w500,
                  color: _isCustomDuration
                      ? (isDark ? V2Colors.mint : V2Colors.deepTosca)
                      : (isDark
                          ? V2Colors.darkTextPrimary
                          : V2Colors.lightTextPrimary),
                ),
              ),
            ),
          ],
        ),

        // Custom Duration Input Field
        if (_isCustomDuration) ...[
          const SizedBox(height: V2Spacing.md),
          TextFormField(
            key: const ValueKey('v2_config_custom_duration_input'),
            controller: _customDurationController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textPrimary, fontSize: 14),
            onChanged: (_) => _validateForm(),
            decoration: InputDecoration(
              hintText: 'Contoh: 40, 75, 120, 365',
              hintStyle: TextStyle(
                color:
                    isDark ? V2Colors.darkTextMuted : V2Colors.lightTextMuted,
                fontSize: 13,
              ),
              suffixText: 'hari',
              suffixStyle:
                  TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
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
              errorText: _durationError,
            ),
          ),
        ],

        if (!_isCustomDuration && _durationError != null)
          Padding(
            padding: const EdgeInsets.only(top: V2Spacing.xs),
            child: Text(
              _durationError!,
              style: TextStyle(
                color: isDark ? V2Colors.peach : Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStartSelectionSection({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required String todayKey,
    required String tomorrowKey,
    required bool isPreBoundary,
  }) {
    final activeBorder = isDark ? V2Colors.mint : V2Colors.deepTosca;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mulai Program',
          style: V2Typography.headingMedium.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          'Tentukan hari operasional awal target mujahadahmu.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: V2Spacing.md),

        // Radio Option: Hari Ini
        InkWell(
          key: const ValueKey('v2_config_start_today'),
          onTap: () {
            setState(() {
              _selectedStartSelection = ProgramStartSelection.today;
            });
          },
          borderRadius: V2Radius.borderMd,
          child: Container(
            padding: const EdgeInsets.all(V2Spacing.md),
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: V2Radius.borderMd,
              border: Border.all(
                color: _selectedStartSelection == ProgramStartSelection.today
                    ? activeBorder
                    : borderColor,
                width: _selectedStartSelection == ProgramStartSelection.today
                    ? 2
                    : 1,
              ),
            ),
            child: Row(
              children: [
                _buildRadioIndicator(
                  isSelected:
                      _selectedStartSelection == ProgramStartSelection.today,
                  activeColor: activeBorder,
                  borderColor: borderColor,
                ),
                const SizedBox(width: V2Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hari Ini',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Tanggal operasional: ${_formatDayKeyIndonesian(todayKey)} ($todayKey)',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: V2Spacing.sm),

        // Radio Option: Besok
        InkWell(
          key: const ValueKey('v2_config_start_tomorrow'),
          onTap: () {
            setState(() {
              _selectedStartSelection = ProgramStartSelection.tomorrow;
            });
          },
          borderRadius: V2Radius.borderMd,
          child: Container(
            padding: const EdgeInsets.all(V2Spacing.md),
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: V2Radius.borderMd,
              border: Border.all(
                color: _selectedStartSelection == ProgramStartSelection.tomorrow
                    ? activeBorder
                    : borderColor,
                width: _selectedStartSelection == ProgramStartSelection.tomorrow
                    ? 2
                    : 1,
              ),
            ),
            child: Row(
              children: [
                _buildRadioIndicator(
                  isSelected:
                      _selectedStartSelection == ProgramStartSelection.tomorrow,
                  activeColor: activeBorder,
                  borderColor: borderColor,
                ),
                const SizedBox(width: V2Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Besok',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Tanggal operasional: ${_formatDayKeyIndonesian(tomorrowKey)} ($tomorrowKey)',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Boundary Explanation Helper
        if (isPreBoundary) ...[
          const SizedBox(height: V2Spacing.sm),
          Container(
            padding: const EdgeInsets.all(V2Spacing.sm),
            decoration: BoxDecoration(
              color: isDark
                  ? V2Colors.mint.withValues(alpha: 0.1)
                  : V2Colors.deepTosca.withValues(alpha: 0.08),
              borderRadius: V2Radius.borderSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                ),
                const SizedBox(width: V2Spacing.xs),
                Expanded(
                  child: Text(
                    'Pukul 00:00 - 02:59 waktu setempat masih terhitung hari operasional kemarin (batas pergantian hari adalah pukul 03:00 waktu setempat).',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReminderSection({
    required BuildContext context,
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderMd,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengingat Harian (Opsional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pengingat bersifat lokal pada perangkat.',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const ValueKey('v2_config_reminder_switch'),
                value: _isReminderEnabled,
                activeThumbColor: isDark ? V2Colors.mint : V2Colors.deepTosca,
                onChanged: (val) {
                  setState(() {
                    _isReminderEnabled = val;
                  });
                  _validateForm();
                },
              ),
            ],
          ),
          if (_isReminderEnabled) ...[
            const Divider(height: V2Spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Waktu Pengingat',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: OutlinedButton.icon(
                    key: const ValueKey('v2_config_reminder_time_picker'),
                    onPressed: () => _pickReminderTime(context),
                    icon: Icon(
                      Icons.schedule,
                      size: 18,
                      color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                    ),
                    label: Text(
                      _formattedReminderTime,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: V2Radius.borderFull,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_reminderError != null)
              Padding(
                padding: const EdgeInsets.only(top: V2Spacing.xs),
                child: Text(
                  _reminderError!,
                  style: TextStyle(
                    color: isDark ? V2Colors.peach : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
      BuildContext context, bool isDark, bool isValid) {
    final bottomBarBg = isDark ? V2Colors.darkSurface : V2Colors.lightSurface;
    final topBorderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 48,
            minWidth: double.infinity,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('v2_config_review_button'),
              onPressed: isValid
                  ? () {
                      _validateForm();
                      if (_durationError == null && _reminderError == null) {
                        final todayKey = _dateService.getTodayDayKey();
                        final tomorrowKey =
                            _dateService.getNextDayKey(todayKey);
                        final effectiveDayKey = _selectedStartSelection ==
                                ProgramStartSelection.today
                            ? todayKey
                            : tomorrowKey;
                        widget.onProceedToReview(
                          _buildDraft(reviewedStartDayKey: effectiveDayKey),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: V2Colors.warmGold,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    isDark ? V2Colors.darkBorder : V2Colors.lightGray,
                disabledForegroundColor:
                    isDark ? V2Colors.darkTextMuted : V2Colors.lightTextMuted,
                shape: const RoundedRectangleBorder(
                  borderRadius: V2Radius.borderFull,
                ),
                elevation: isValid ? 2 : 0,
              ),
              child: const Text(
                'Lanjut ke Review Program',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadioIndicator({
    required bool isSelected,
    required Color activeColor,
    required Color borderColor,
  }) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? activeColor : borderColor,
          width: 2.0,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                ),
              ),
            )
          : null,
    );
  }
}
