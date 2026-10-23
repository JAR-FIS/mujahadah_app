import 'package:flutter/material.dart';

import '../../../core/date/date_service.dart';
import '../../../models/program_v2_model.dart';
import '../../../models/v2_ibadah_catalog_item.dart';
import '../../../models/v2_program_config_draft.dart';
import '../../../services/program_v2_creation_service.dart';
import '../../../theme/v2_design_tokens.dart';

/// Mandatory Review Program Screen.
///
/// Final confirmation gate before Program creation:
/// - Displays full configuration summary: Worship title, Target duration, Effective start day, and Reminder.
/// - Presents approved commitment and niat messaging.
/// - Requires explicit action: "Kembali & Edit" (preserves draft) or "Buat Program".
/// - Fail-closed: "Buat Program" is disabled with honest guidance if no creation handler is wired.
/// - Protected against duplicate submissions from rapid taps.
/// - Transparent error reporting and safe retry on persistence failures.
///
/// Note on cross-boundary race condition:
/// Between the UI pre-dispatch check of current operational day and the internal
/// execution of [ProgramV2CreationService.createProgram] capturing [DateService.now],
/// an OS thread preemption or delay could theoretically cross the 03:00:00 boundary.
/// In a future domain-level task, this can be eliminated atomically by adding an
/// `expectedStartDayKey` parameter to [CreateProgramV2Request] and asserting it
/// within the synchronized lock of [ProgramV2CreationService].
class V2ProgramReviewView extends StatefulWidget {
  final V2IbadahCatalogItem item;
  final V2ProgramConfigDraft draft;
  final DateService? dateService;
  final ProgramV2CreationService? creationService;
  final ProgramCreationCallback? onConfirmCreate;
  final VoidCallback onBackAndEdit;
  final ValueChanged<ProgramV2Model>? onProgramCreated;

  const V2ProgramReviewView({
    super.key,
    required this.item,
    required this.draft,
    this.dateService,
    this.creationService,
    this.onConfirmCreate,
    required this.onBackAndEdit,
    this.onProgramCreated,
  });

  @override
  State<V2ProgramReviewView> createState() => _V2ProgramReviewViewState();
}

class _V2ProgramReviewViewState extends State<V2ProgramReviewView> {
  late final DateService _dateService;
  late final String _reviewedDayKey;
  bool _isDispatching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dateService = widget.dateService ?? DateService();
    _reviewedDayKey =
        widget.draft.reviewedStartDayKey ?? _resolveEffectiveDayKey();
  }

  String _resolveEffectiveDayKey() {
    final todayKey = _dateService.getTodayDayKey();
    return widget.draft.startSelection == ProgramStartSelection.today
        ? todayKey
        : _dateService.getNextDayKey(todayKey);
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

  String _mapFailureReasonToIndonesian(
      ProgramCreationFailureReason? reason, String? rawMessage) {
    switch (reason) {
      case ProgramCreationFailureReason.duplicateActiveProgram:
        return 'Program aktif untuk ibadah ini sudah ada. Selesaikan atau evaluasi program sebelumnya terlebih dahulu.';
      case ProgramCreationFailureReason.invalidDuration:
        return 'Target durasi tidak valid (harus 40 hingga 365 hari).';
      case ProgramCreationFailureReason.invalidReminderTime:
        return 'Format waktu pengingat tidak valid.';
      case ProgramCreationFailureReason.persistenceError:
        return 'Gagal menyimpan program ke penyimpanan perangkat. Silakan coba lagi.';
      case ProgramCreationFailureReason.idCollision:
      case ProgramCreationFailureReason.idGenerationError:
        return 'Terjadi kendala pembuatan identitas program. Silakan coba lagi.';
      case ProgramCreationFailureReason.emptyIbadahId:
      case ProgramCreationFailureReason.emptyIbadahName:
        return 'Data ibadah tidak lengkap.';
      case ProgramCreationFailureReason.invalidRestartSource:
        return 'Program riwayat asal tidak valid atau belum berstatus selesai/terhenti.';
      case null:
        return 'Terjadi kendala saat membuat program. Silakan coba lagi.';
    }
  }

  Future<void> _handleCreate() async {
    if (_isDispatching) return;

    final hasHandler =
        widget.onConfirmCreate != null || widget.creationService != null;
    if (!hasHandler) return;

    // FIX 2: Compare current derived operational start day against the reviewed snapshot.
    final currentEffectiveDayKey = _resolveEffectiveDayKey();
    if (currentEffectiveDayKey != _reviewedDayKey) {
      setState(() {
        _errorMessage =
            'Hari operasional telah berganti melewati batas pukul 03:00. '
            'Silakan kembali ke konfigurasi untuk meninjau dan menyetujui tanggal operasional terbaru.';
      });
      return;
    }

    setState(() {
      _isDispatching = true;
      _errorMessage = null;
    });

    final request = CreateProgramV2Request(
      ibadahId: widget.item.id,
      ibadahNameSnapshot: widget.item.namaIbadah,
      targetDays: widget.draft.effectiveTargetDays,
      startSelection: widget.draft.startSelection,
      reminderTime:
          widget.draft.isReminderEnabled ? widget.draft.reminderTime : null,
      restartedFromProgramId: widget.draft.restartedFromProgramId,
    );

    try {
      final ProgramCreationResult result;
      if (widget.onConfirmCreate != null) {
        result = await widget.onConfirmCreate!(request);
      } else {
        result = await widget.creationService!.createFromRequest(request);
      }

      if (!mounted) return;

      setState(() {
        _isDispatching = false;
      });

      if (result.isSuccess && result.program != null) {
        widget.onProgramCreated?.call(result.program!);
      } else {
        setState(() {
          _errorMessage = _mapFailureReasonToIndonesian(
            result.failureReason,
            result.errorMessage,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDispatching = false;
        _errorMessage =
            'Terjadi kendala komunikasi penyimpanan. Silakan coba lagi.';
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

    final startLabel =
        widget.draft.startSelection == ProgramStartSelection.today
            ? 'Hari Ini'
            : 'Besok';

    final hasHandler =
        widget.onConfirmCreate != null || widget.creationService != null;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, isDark, textPrimary),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.lg,
                  vertical: V2Spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    _buildSummaryCard(
                      isDark: isDark,
                      surfaceCard: surfaceCard,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      effectiveDayKey: _reviewedDayKey,
                      startLabel: startLabel,
                    ),
                    const SizedBox(height: V2Spacing.lg),

                    // Niat & Komitmen Card
                    _buildNiatCard(
                      isDark: isDark,
                      surfaceCard: surfaceCard,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: V2Spacing.lg),

                    // Error Alert (if failure occurred)
                    if (_errorMessage != null)
                      _buildErrorBanner(isDark, _errorMessage!),

                    const SizedBox(height: V2Spacing.xl),
                  ],
                ),
              ),
            ),

            // Bottom Actions (Kembali & Edit / Buat Program)
            _buildBottomActionBar(context, isDark, hasHandler),
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
            label: 'Kembali dan Edit Konfigurasi',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                key: const ValueKey('v2_program_review_back_button'),
                icon: const Icon(Icons.arrow_back),
                color: textPrimary,
                onPressed: widget.onBackAndEdit,
                tooltip: 'Kembali & Edit',
              ),
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              'Review Program',
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

  Widget _buildSummaryCard({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required String effectiveDayKey,
    required String startLabel,
  }) {
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
          Text(
            'Ringkasan Program',
            style: V2Typography.headingMedium.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V2Spacing.md),

          // Restart Origin Indicator (if restarting from history)
          if (widget.draft.restartedFromProgramId != null) ...[
            Container(
              key: const ValueKey('v2_review_restart_notice'),
              padding: const EdgeInsets.symmetric(
                horizontal: V2Spacing.md,
                vertical: V2Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? V2Colors.mint.withValues(alpha: 0.15)
                    : V2Colors.deepTosca.withValues(alpha: 0.08),
                borderRadius: V2Radius.borderMd,
                border: Border.all(
                  color: isDark
                      ? V2Colors.mint.withValues(alpha: 0.3)
                      : V2Colors.deepTosca.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.replay_rounded,
                    size: 18,
                    color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                  ),
                  const SizedBox(width: V2Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Memulai Perjalanan Baru',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? V2Colors.mint : V2Colors.deepTosca,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Melanjutkan ikhtiar dari riwayat sebelumnya (${widget.item.namaIbadah}). Riwayat dan catatan evaluasi lama tetap tersimpan.',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: V2Spacing.md),
          ],

          // Worship Title
          _buildDetailRow(
            label: 'Ibadah',
            value: widget.item.namaIbadah,
            valueKey: 'v2_review_item_name',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isEmphasized: true,
          ),
          const Divider(height: V2Spacing.lg),

          // Target Duration
          _buildDetailRow(
            label: 'Target Durasi',
            value: '${widget.draft.effectiveTargetDays} Hari Berturut-turut',
            valueKey: 'v2_review_target_days',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            highlightColor: isDark ? V2Colors.peach : V2Colors.warmGold,
          ),
          const Divider(height: V2Spacing.lg),

          // Start Day
          _buildDetailRow(
            label: 'Mulai Operasional',
            value: '$startLabel (${_formatDayKeyIndonesian(effectiveDayKey)})',
            valueKey: 'v2_review_start_day',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const Divider(height: V2Spacing.lg),

          // Reminder Time
          _buildDetailRow(
            label: 'Pengingat Harian',
            value: widget.draft.isReminderEnabled
                ? 'Pukul ${widget.draft.reminderTime}'
                : 'Tidak Diaktifkan',
            valueKey: 'v2_review_reminder',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required String valueKey,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    Color? highlightColor,
    bool isEmphasized = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            key: ValueKey(valueKey),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w600,
              color: highlightColor ?? textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNiatCard({
    required bool isDark,
    required Color surfaceCard,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final goldColor = isDark ? V2Colors.peach : V2Colors.warmGold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: V2Radius.borderLg,
        border: Border.all(color: goldColor.withValues(alpha: 0.5)),
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism_outlined,
                  color: goldColor, size: 20),
              const SizedBox(width: V2Spacing.xs),
              Expanded(
                child: Text(
                  'Komitmen Mujahadah',
                  style: V2Typography.headingMedium.copyWith(
                    color: goldColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Spacing.sm),
          Text(
            'Bismillah, saya berniat menjaga istiqomah ${widget.item.namaIbadah} selama ${widget.draft.effectiveTargetDays} hari berturut-turut karena Allah Ta\'ala.',
            key: const ValueKey('v2_review_niat_text'),
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark, String message) {
    return Container(
      key: const ValueKey('v2_review_error_banner'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                height: 1.4,
                color: isDark ? V2Colors.peach : Colors.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
      BuildContext context, bool isDark, bool hasHandler) {
    final bottomBarBg = isDark ? V2Colors.darkSurface : V2Colors.lightSurface;
    final topBorderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    final isCreateEnabled = hasHandler && !_isDispatching;

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
            if (!hasHandler)
              Padding(
                padding: const EdgeInsets.only(bottom: V2Spacing.sm),
                child: Text(
                  'Layanan pembuatan program belum tersedia.',
                  key: const ValueKey('v2_review_unavailable_notice'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? V2Colors.darkTextMuted
                        : V2Colors.lightTextMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                // Kembali & Edit
                Expanded(
                  flex: 2,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton(
                      key: const ValueKey('v2_review_edit_button'),
                      onPressed: _isDispatching ? null : widget.onBackAndEdit,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark
                              ? V2Colors.darkBorder
                              : V2Colors.lightBorder,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: V2Radius.borderFull,
                        ),
                      ),
                      child: Text(
                        'Kembali & Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? V2Colors.darkTextPrimary
                              : V2Colors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: V2Spacing.sm),

                // Buat Program
                Expanded(
                  flex: 3,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ElevatedButton(
                      key: const ValueKey('v2_review_create_button'),
                      onPressed: isCreateEnabled ? _handleCreate : null,
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
                        elevation: isCreateEnabled ? 2 : 0,
                      ),
                      child: _isDispatching
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
                              'Buat Program',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
