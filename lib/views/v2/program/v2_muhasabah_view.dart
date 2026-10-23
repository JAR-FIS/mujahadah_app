import 'package:flutter/material.dart';

import '../../../core/date/date_service.dart';
import '../../../models/program_v2_model.dart';
import '../../../repositories/program_v2_repository.dart';
import '../../../services/program_v2_journey_orchestrator.dart';
import '../../../services/program_v2_muhasabah_service.dart';
import '../../../theme/v2_design_tokens.dart';

/// Typed representation of a selectable Muhasabah failure reason option.
class MuhasabahReasonOption {
  final String code;
  final String label;
  final String? description;

  const MuhasabahReasonOption({
    required this.code,
    required this.label,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuhasabahReasonOption &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          label == other.label;

  @override
  int get hashCode => Object.hash(code, label);
}

/// Typed callback signature for submitting Muhasabah failure evaluation.
typedef MuhasabahSubmitCallback = Future<OrchestratedMuhasabahResult> Function({
  required String programId,
  required String reasonCode,
  required String reasonLabelSnapshot,
  String? note,
});

/// Screen S22 — Muhasabah / Pending Failure Evaluation View.
///
/// Implements the authoritative, offline-first Muhasabah transition from a
/// [ProgramV2Model.statusPendingFailure] program to the domain's [statusFailed]
/// or [statusWarning] terminal result.
///
/// Architectural Guarantees:
/// 1. Authoritative Domain Derivation: Never calculates FAILED vs WARNING in UI;
///    displays only the persisted final status returned by the domain.
/// 2. Mandatory Reason: Reason code and label snapshot are strictly mandatory.
///    Submission is disabled without a valid, selected reason.
/// 3. Fail-Closed Reason Content: If no approved reason options are supplied,
///    renders an honest fail-closed banner and disables submission.
/// 4. Explicit Confirmation: User must confirm before the terminal outcome is persisted.
/// 5. Lifecycle & Stale Protection: Responds to app resume, checks program integrity,
///    and prevents cross-program async race conditions.
/// 6. Safe Cancel & Back: Back or cancellation leaves the pending failure intact
///    with zero writes or mutations.
class V2MuhasabahView extends StatefulWidget {
  final ProgramV2Model program;
  final VoidCallback onBack;
  final ProgramV2Repository? programRepository;
  final ProgramV2JourneyOrchestrator? orchestrator;
  final ProgramV2MuhasabahService? muhasabahService;
  final MuhasabahSubmitCallback? onMuhasabahSubmit;
  final List<MuhasabahReasonOption>? reasonOptions;
  final DateService? dateService;
  final ValueChanged<ProgramV2Model>? onCompleted;
  final VoidCallback? onBackToHub;
  final bool isActiveTab;

  const V2MuhasabahView({
    super.key,
    required this.program,
    required this.onBack,
    this.programRepository,
    this.orchestrator,
    this.muhasabahService,
    this.onMuhasabahSubmit,
    this.reasonOptions,
    this.dateService,
    this.onCompleted,
    this.onBackToHub,
    this.isActiveTab = true,
  });

  @override
  State<V2MuhasabahView> createState() => _V2MuhasabahViewState();
}

class _V2MuhasabahViewState extends State<V2MuhasabahView>
    with WidgetsBindingObserver {
  late ProgramV2Model _currentProgram;
  MuhasabahReasonOption? _selectedReason;
  late TextEditingController _noteController;
  bool _isSubmitting = false;
  String? _errorMessage;
  OrchestratedMuhasabahResult? _terminalResult;
  int _submissionGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentProgram = widget.program;
    _noteController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant V2MuhasabahView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.program.id != widget.program.id) {
      _submissionGeneration++;
      _currentProgram = widget.program;
      _selectedReason = null;
      _noteController.clear();
      _isSubmitting = false;
      _errorMessage = null;
      _terminalResult = null;
    } else if (oldWidget.program != widget.program) {
      _currentProgram = widget.program;
    }

    if (oldWidget.reasonOptions != widget.reasonOptions) {
      if (_selectedReason != null) {
        final options = widget.reasonOptions;
        if (options == null || options.isEmpty) {
          _selectedReason = null;
        } else {
          final stillExists = options.any((opt) =>
              opt.code.trim().isNotEmpty &&
              opt.label.trim().isNotEmpty &&
              opt.code.trim() == _selectedReason!.code.trim() &&
              opt.label.trim() == _selectedReason!.label.trim());
          if (!stillExists) {
            _selectedReason = null;
          }
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProgramState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteController.dispose();
    super.dispose();
  }

  void _refreshProgramState() {
    if (widget.programRepository == null) return;
    try {
      final fresh = widget.programRepository!.getById(_currentProgram.id);
      if (mounted) {
        setState(() {
          if (fresh != null) {
            _currentProgram = fresh;
          } else {
            _errorMessage =
                'Program tidak lagi ditemukan di penyimpanan data lokal.';
          }
        });
      }
    } catch (_) {}
  }

  bool get _hasHandler =>
      widget.onMuhasabahSubmit != null ||
      widget.orchestrator != null ||
      widget.muhasabahService != null;

  bool get _isReasonValid {
    final reason = _selectedReason;
    if (reason == null) return false;
    final cleanCode = reason.code.trim();
    final cleanLabel = reason.label.trim();
    if (cleanCode.isEmpty || cleanLabel.isEmpty) return false;
    final options = widget.reasonOptions;
    if (options == null || options.isEmpty) return false;
    return options.any((opt) =>
        opt.code.trim().isNotEmpty &&
        opt.label.trim().isNotEmpty &&
        opt.code.trim() == cleanCode &&
        opt.label.trim() == cleanLabel);
  }

  bool get _canSubmit {
    return _isReasonValid &&
        !_isSubmitting &&
        _hasHandler &&
        _currentProgram.status == ProgramV2Model.statusPendingFailure &&
        _terminalResult == null;
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case ProgramV2Model.statusActive:
        return 'Aktif';
      case ProgramV2Model.statusPendingFailure:
        return 'Perlu Muhasabah';
      case ProgramV2Model.statusSuccess:
        return 'Selesai';
      case ProgramV2Model.statusFailed:
        return 'Belum Selesai';
      case ProgramV2Model.statusWarning:
        return 'Hampir Selesai';
      default:
        return status;
    }
  }

  String _formatMissedDay(String dayKey) {
    try {
      final parts = dayKey.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
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
        if (m >= 1 && m <= 12) {
          return '$d ${months[m - 1]} $y';
        }
      }
    } catch (_) {}
    return dayKey;
  }

  void _showConfirmDialog(BuildContext context, bool isDark) {
    if (!_canSubmit) return;

    final dialogBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    showDialog<bool>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (dialogCtx) => AlertDialog(
        key: const ValueKey('v2_muhasabah_confirm_dialog'),
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: V2Radius.borderLg),
        title: Text(
          'Konfirmasi Muhasabah',
          style: V2Typography.headingMedium
              .copyWith(color: textPrimary, fontSize: 18),
        ),
        content: Text(
          'Setelah disimpan, program ibadah ini akan diselesaikan secara permanen berdasarkan evaluasi hari yang terlewat. Tindakan ini tidak dapat dibatalkan. Lanjutkan simpan?',
          style: V2Typography.bodyMedium.copyWith(color: textSecondary),
        ),
        actions: [
          TextButton(
            key: const ValueKey('v2_muhasabah_dialog_cancel'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('v2_muhasabah_dialog_confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: V2Colors.warmGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: V2Radius.borderMd),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop(true);
              _executeSubmission();
            },
            child: const Text(
              'Ya, Simpan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSubmission() async {
    if (_isSubmitting) return;

    final reason = _selectedReason;
    if (reason == null || !_isReasonValid) {
      setState(() {
        _errorMessage =
            'Alasan muhasabah yang valid wajib dipilih dari katalog resmi.';
      });
      return;
    }

    if (_currentProgram.status != ProgramV2Model.statusPendingFailure) {
      setState(() {
        _errorMessage =
            'Program tidak lagi dalam status perlu muhasabah (${_currentProgram.status}).';
      });
      return;
    }

    final targetProgramId = _currentProgram.id;
    final expectedMissedDayKey = _currentProgram.pendingMissedDayKey;
    if (expectedMissedDayKey == null || expectedMissedDayKey.trim().isEmpty) {
      setState(() {
        _errorMessage =
            'Data program tidak valid: tanggal interupsi tidak ditemukan.';
      });
      return;
    }

    final currentGen = ++_submissionGeneration;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final cleanReasonCode = reason.code.trim();
    final cleanReasonLabel = reason.label.trim();
    final rawNote = _noteController.text.trim();
    final cleanNote = rawNote.isEmpty ? null : rawNote;

    try {
      final OrchestratedMuhasabahResult result;

      if (widget.onMuhasabahSubmit != null) {
        result = await widget.onMuhasabahSubmit!(
          programId: targetProgramId,
          reasonCode: cleanReasonCode,
          reasonLabelSnapshot: cleanReasonLabel,
          note: cleanNote,
        );
      } else if (widget.orchestrator != null) {
        result = await widget.orchestrator!.submitMuhasabah(
          programId: targetProgramId,
          reasonCode: cleanReasonCode,
          reasonLabelSnapshot: cleanReasonLabel,
          note: cleanNote,
        );
      } else if (widget.muhasabahService != null) {
        final svcResult = await widget.muhasabahService!.finalizeFailure(
          programId: targetProgramId,
          reasonCode: cleanReasonCode,
          reasonLabelSnapshot: cleanReasonLabel,
          note: cleanNote,
        );
        result = _mapServiceResult(svcResult, targetProgramId);
      } else {
        if (!mounted ||
            _submissionGeneration != currentGen ||
            _currentProgram.id != targetProgramId) {
          return;
        }
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'Layanan muhasabah belum terhubung. Finalisasi program tidak dapat diproses.';
        });
        return;
      }

      if (!mounted ||
          _submissionGeneration != currentGen ||
          _currentProgram.id != targetProgramId) {
        return;
      }

      if (result.isSuccess) {
        // P1-01: Validate program ID and typed terminal status
        final validStatus = result.finalStatus == ProgramV2Model.statusFailed ||
            result.finalStatus == ProgramV2Model.statusWarning;

        if (!validStatus || result.programId != targetProgramId) {
          setState(() {
            _isSubmitting = false;
            _errorMessage =
                'Respon finalisasi tidak memuat status terminal yang valid.';
          });
          return;
        }

        final ProgramV2Model updatedProgram;

        if (widget.programRepository != null) {
          final reloaded = widget.programRepository!.getById(targetProgramId);
          if (reloaded == null ||
              reloaded.id != targetProgramId ||
              reloaded.status != result.finalStatus ||
              (reloaded.status != ProgramV2Model.statusFailed &&
                  reloaded.status != ProgramV2Model.statusWarning)) {
            setState(() {
              _isSubmitting = false;
              _errorMessage =
                  'Gagal memverifikasi status terminal program yang tersimpan di penyimpanan lokal.';
            });
            return;
          }
          updatedProgram = reloaded;
        } else {
          if (result.program == null ||
              result.program!.id != targetProgramId ||
              result.program!.status != result.finalStatus ||
              (result.program!.status != ProgramV2Model.statusFailed &&
                  result.program!.status != ProgramV2Model.statusWarning)) {
            setState(() {
              _isSubmitting = false;
              _errorMessage =
                  'Respon finalisasi tidak memuat data program terminal yang lengkap dan konsisten.';
            });
            return;
          }
          updatedProgram = result.program!;
        }

        // P1-05: Validate returned program model consistency across both modes
        if (result.program == null ||
            result.program!.id != targetProgramId ||
            result.program!.status != result.finalStatus) {
          setState(() {
            _isSubmitting = false;
            _errorMessage =
                'Respon finalisasi tidak memuat data program terminal yang lengkap dan konsisten.';
          });
          return;
        }

        // P1-05: Full failure record receipt validation across BOTH modes
        final failureRec = result.failureRecord;
        if (failureRec == null) {
          setState(() {
            _isSubmitting = false;
            _errorMessage =
                'Respon finalisasi tidak memuat bukti pencatatan muhasabah (failure record).';
          });
          return;
        }

        if (failureRec.programId != targetProgramId ||
            failureRec.missedDayKey != expectedMissedDayKey ||
            failureRec.reasonCode.trim() != cleanReasonCode ||
            failureRec.reasonLabelSnapshot.trim() != cleanReasonLabel ||
            failureRec.id.trim().isEmpty) {
          setState(() {
            _isSubmitting = false;
            _errorMessage =
                'Respon pencatatan muhasabah tidak sesuai dengan interupsi program atau alasan yang dipilih.';
          });
          return;
        }

        setState(() {
          _currentProgram = updatedProgram;
          _terminalResult = result;
          _isSubmitting = false;
        });

        widget.onCompleted?.call(updatedProgram);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = _resolveErrorMessage(result);
        });
      }
    } catch (_) {
      if (!mounted ||
          _submissionGeneration != currentGen ||
          _currentProgram.id != targetProgramId) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Terjadi kesalahan tidak terduga saat menyimpan muhasabah.';
      });
    }
  }

  OrchestratedMuhasabahResult _mapServiceResult(
    ProgramMuhasabahResult svcResult,
    String programId,
  ) {
    switch (svcResult.outcome) {
      case ProgramMuhasabahOutcome.failedCreated:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.failedCreated,
          programId: programId,
          finalStatus: svcResult.finalStatus,
          program: svcResult.program,
          failureRecord: svcResult.failureRecord,
          completedDays: svcResult.completedDays,
        );
      case ProgramMuhasabahOutcome.warningCreated:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.warningCreated,
          programId: programId,
          finalStatus: svcResult.finalStatus,
          program: svcResult.program,
          failureRecord: svcResult.failureRecord,
          completedDays: svcResult.completedDays,
        );
      case ProgramMuhasabahOutcome.alreadyFinalized:
        return OrchestratedMuhasabahResult.fromOutcome(
          outcome: OrchestratedMuhasabahOutcome.alreadyFinalized,
          programId: programId,
          finalStatus: svcResult.finalStatus,
          program: svcResult.program,
          failureRecord: svcResult.failureRecord,
          completedDays: svcResult.completedDays,
        );
      case ProgramMuhasabahOutcome.programNotPending:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.programNotPending,
          programId: programId,
          message: svcResult.errorMessage,
        );
      case ProgramMuhasabahOutcome.invalidReason:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.invalidReason,
          programId: programId,
          message: svcResult.errorMessage,
        );
      case ProgramMuhasabahOutcome.reasonConflict:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.reasonConflict,
          programId: programId,
          message: svcResult.errorMessage,
        );
      case ProgramMuhasabahOutcome.invalidProgramId:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.invalidProgramId,
          programId: programId,
          message: svcResult.errorMessage,
        );
      case ProgramMuhasabahOutcome.programNotFound:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.programNotFound,
          programId: programId,
          message: svcResult.errorMessage,
        );
      case ProgramMuhasabahOutcome.dataIntegrityError:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.dataIntegrityError,
          programId: programId,
          message: svcResult.errorMessage,
        );
      case ProgramMuhasabahOutcome.persistenceError:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.persistenceError,
          programId: programId,
          message: svcResult.errorMessage,
        );
      case ProgramMuhasabahOutcome.unexpectedError:
        return OrchestratedMuhasabahResult.failure(
          outcome: OrchestratedMuhasabahOutcome.unexpectedError,
          programId: programId,
          message: svcResult.errorMessage,
        );
    }
  }

  String _resolveErrorMessage(OrchestratedMuhasabahResult result) {
    switch (result.outcome) {
      case OrchestratedMuhasabahOutcome.reasonConflict:
        return 'Alasan yang diajukan berbeda dengan catatan evaluasi yang sudah tersimpan.';
      case OrchestratedMuhasabahOutcome.programNotPending:
        return 'Program tidak lagi dalam status perlu muhasabah.';
      case OrchestratedMuhasabahOutcome.programNotFound:
        return 'Program tidak ditemukan di penyimpanan data lokal.';
      case OrchestratedMuhasabahOutcome.invalidReason:
        return 'Alasan muhasabah tidak valid atau kosong.';
      case OrchestratedMuhasabahOutcome.persistenceError:
        return 'Gagal menyimpan evaluasi karena kendala penyimpanan lokal.';
      case OrchestratedMuhasabahOutcome.dataIntegrityError:
        return 'Terjadi ketidaksesuaian data pada catatan program.';
      default:
        return result.errorMessage ?? 'Gagal menyimpan evaluasi muhasabah.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? V2Colors.darkScaffoldBackground
        : V2Colors.lightScaffoldBackground;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;

    return Scaffold(
      key: const ValueKey('v2_muhasabah_view'),
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context, isDark, textPrimary),
            Expanded(
              child: _terminalResult != null
                  ? _buildTerminalCompletedView(context, isDark)
                  : _currentProgram.status !=
                          ProgramV2Model.statusPendingFailure
                      ? _buildNonPendingStatusView(context, isDark)
                      : _buildEvaluationForm(context, isDark),
            ),
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
                key: const ValueKey('v2_muhasabah_back_button'),
                icon: const Icon(Icons.arrow_back),
                color: textPrimary,
                tooltip: 'Kembali',
                onPressed: _isSubmitting ? null : widget.onBack,
              ),
            ),
          ),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              _terminalResult != null ? 'Hasil Muhasabah' : 'Muhasabah Program',
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

  Widget _buildNonPendingStatusView(BuildContext context, bool isDark) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    return SingleChildScrollView(
      key: const ValueKey('v2_muhasabah_non_pending_notice'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(V2Spacing.xl),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: V2Radius.borderLg,
              border: Border.all(
                color: isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 48,
                  color: isDark ? V2Colors.peach : const Color(0xFF8A5B00),
                ),
                const SizedBox(height: V2Spacing.md),
                Text(
                  'Program Tidak Memerlukan Muhasabah',
                  style: V2Typography.headingMedium.copyWith(
                    color: textPrimary,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: V2Spacing.sm),
                Text(
                  'Status program saat ini adalah ${_getStatusLabel(_currentProgram.status)}. Halaman evaluasi muhasabah hanya berlaku untuk program yang berstatus perlu muhasabah.',
                  style: V2Typography.bodyMedium.copyWith(color: textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: V2Spacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    key: const ValueKey('v2_muhasabah_non_pending_back_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(
                        color:
                            isDark ? V2Colors.darkBorder : V2Colors.lightBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: V2Radius.borderMd,
                      ),
                    ),
                    onPressed: widget.onBack,
                    child: const Text('Kembali'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationForm(BuildContext context, bool isDark) {
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;
    final accentPeach = isDark ? V2Colors.peach : const Color(0xFF8A5B00);

    final reasonOptions = widget.reasonOptions;
    final hasReasonOptions = reasonOptions != null && reasonOptions.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Spacing.lg,
        vertical: V2Spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Empathetic Program Context Card
          Container(
            key: const ValueKey('v2_muhasabah_context_card'),
            padding: const EdgeInsets.all(V2Spacing.lg),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: V2Radius.borderLg,
              border: Border.all(
                color: isDark
                    ? V2Colors.peach.withValues(alpha: 0.3)
                    : V2Colors.peach.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(V2Spacing.xs),
                      decoration: BoxDecoration(
                        color: accentPeach.withValues(alpha: 0.15),
                        borderRadius: V2Radius.borderSm,
                      ),
                      child: Icon(
                        Icons.self_improvement_rounded,
                        color: accentPeach,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: V2Spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V2Spacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentPeach.withValues(alpha: 0.15),
                        borderRadius: V2Radius.borderSm,
                      ),
                      child: Text(
                        'Perlu Muhasabah',
                        style: V2Typography.bodySmall.copyWith(
                          color: accentPeach,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: V2Spacing.sm),
                Text(
                  _currentProgram.ibadahNameSnapshot,
                  key: const ValueKey('v2_muhasabah_program_name'),
                  style: V2Typography.headingMedium.copyWith(
                    color: textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target: ${_currentProgram.targetDays} Hari',
                  style: V2Typography.bodySmall.copyWith(
                    color: textSecondary,
                  ),
                ),
                if (_currentProgram.pendingMissedDayKey != null) ...[
                  const SizedBox(height: V2Spacing.md),
                  Container(
                    key: const ValueKey('v2_muhasabah_missed_day'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: V2Spacing.md,
                      vertical: V2Spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: V2Radius.borderSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: textSecondary,
                        ),
                        const SizedBox(width: V2Spacing.xs),
                        Flexible(
                          child: Text(
                            'Hari terlewat: ${_formatMissedDay(_currentProgram.pendingMissedDayKey!)}',
                            style: V2Typography.bodySmall.copyWith(
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: V2Spacing.md),
                Text(
                  'Perjalanan ibadah terhenti karena terdapat hari yang terlewat. Melalui muhasabah ini, kita mengevaluasi kendala secara jujur dan tenang untuk menjaga komitmen di masa depan.',
                  style: V2Typography.bodyMedium.copyWith(
                    color: textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: V2Spacing.lg),

          // 2. Reason Selection Section
          Text(
            'Pilih Alasan Kendala',
            style: V2Typography.headingMedium.copyWith(
              color: textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: V2Spacing.xs),
          Text(
            'Pilih satu alasan utama yang menyebabkan ibadah terlewat. Alasan ini wajib dipilih untuk menyelesaikan evaluasi.',
            style: V2Typography.bodySmall.copyWith(color: textSecondary),
          ),
          const SizedBox(height: V2Spacing.md),

          if (!hasReasonOptions) ...[
            // Fail-closed banner when no approved reason catalog is supplied
            Container(
              key: const ValueKey('v2_muhasabah_no_reasons_notice'),
              padding: const EdgeInsets.all(V2Spacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? V2Colors.peach.withValues(alpha: 0.1)
                    : const Color(0xFFFFF9E6),
                borderRadius: V2Radius.borderMd,
                border: Border.all(
                  color: isDark ? V2Colors.peach : const Color(0xFFD4A017),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: accentPeach,
                    size: 22,
                  ),
                  const SizedBox(width: V2Spacing.md),
                  Expanded(
                    child: Text(
                      'Pilihan alasan muhasabah belum tersedia dari katalog resmi. Proses muhasabah tidak dapat dilanjutkan tanpa alasan yang terverifikasi.',
                      style: V2Typography.bodyMedium.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Render selectable reason list
            Container(
              key: const ValueKey('v2_muhasabah_reasons_list'),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: V2Radius.borderLg,
                border: Border.all(color: borderColor),
              ),
              child: ClipRRect(
                borderRadius: V2Radius.borderLg,
                child: Column(
                  children: [
                    for (int i = 0; i < reasonOptions.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                      _buildReasonTile(
                        context,
                        option: reasonOptions[i],
                        isSelected: _selectedReason == reasonOptions[i],
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: V2Spacing.lg),

          // 3. Optional Freeform Notes Section
          Text(
            'Catatan Refleksi Pribadi (Opsional)',
            style: V2Typography.headingMedium.copyWith(
              color: textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: V2Spacing.xs),
          Text(
            'Tuliskan catatan tambahan untuk introspeksi diri atau komitmen di masa depan (tidak menggantikan alasan utama di atas).',
            style: V2Typography.bodySmall.copyWith(color: textSecondary),
          ),
          const SizedBox(height: V2Spacing.md),
          TextField(
            key: const ValueKey('v2_muhasabah_note_input'),
            controller: _noteController,
            maxLines: 3,
            maxLength: 500,
            enabled: !_isSubmitting,
            style: V2Typography.bodyMedium.copyWith(color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Tuliskan catatan refleksi Anda di sini...',
              hintStyle: V2Typography.bodyMedium.copyWith(color: textSecondary),
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.all(V2Spacing.md),
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
                borderSide: const BorderSide(
                  color: V2Colors.warmGold,
                  width: 1.5,
                ),
              ),
            ),
          ),

          // 4. Missing handler notice if not wired
          if (!_hasHandler) ...[
            const SizedBox(height: V2Spacing.sm),
            Container(
              key: const ValueKey('v2_muhasabah_unwired_notice'),
              padding: const EdgeInsets.all(V2Spacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: V2Radius.borderMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: textSecondary,
                  ),
                  const SizedBox(width: V2Spacing.sm),
                  Expanded(
                    child: Text(
                      'Layanan muhasabah belum terhubung. Tombol simpan dinonaktifkan.',
                      style: V2Typography.bodySmall.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Error Banner if submission failed
          if (_errorMessage != null) ...[
            const SizedBox(height: V2Spacing.md),
            Container(
              key: const ValueKey('v2_muhasabah_error_banner'),
              padding: const EdgeInsets.all(V2Spacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                borderRadius: V2Radius.borderMd,
                border: Border.all(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFD32F2F),
                    size: 20,
                  ),
                  const SizedBox(width: V2Spacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: V2Typography.bodySmall.copyWith(
                        color: const Color(0xFFD32F2F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: V2Spacing.xl),

          // 6. Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const ValueKey('v2_muhasabah_cancel_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: V2Radius.borderMd,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : widget.onBack,
                    child: const Text(
                      'Batal',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: V2Spacing.md),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    key: const ValueKey('v2_muhasabah_submit_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: V2Colors.warmGold,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      disabledForegroundColor:
                          isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: V2Radius.borderMd,
                      ),
                    ),
                    onPressed: _canSubmit
                        ? () => _showConfirmDialog(context, isDark)
                        : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Simpan Muhasabah',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V2Spacing.xl),
        ],
      ),
    );
  }

  Widget _buildReasonTile(
    BuildContext context, {
    required MuhasabahReasonOption option,
    required bool isSelected,
    required bool isDark,
  }) {
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;
    final activeColor = V2Colors.warmGold;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;

    return Semantics(
      key: ValueKey('v2_muhasabah_reason_${option.code}'),
      button: true,
      selected: isSelected,
      label: 'Alasan: ${option.label}',
      child: InkWell(
        onTap: _isSubmitting
            ? null
            : () {
                setState(() {
                  _selectedReason = option;
                  _errorMessage = null;
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: V2Spacing.md,
            vertical: V2Spacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: V2Spacing.sm),
                child: _buildRadioIndicator(
                  isSelected: isSelected,
                  activeColor: activeColor,
                  borderColor: borderColor,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: V2Typography.bodyMedium.copyWith(
                        color: textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (option.description != null &&
                        option.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.description!,
                        style: V2Typography.bodySmall.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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

  Widget _buildTerminalCompletedView(BuildContext context, bool isDark) {
    final result = _terminalResult!;
    final cardBg =
        isDark ? V2Colors.darkSurfaceCard : V2Colors.lightSurfaceCard;
    final borderColor = isDark ? V2Colors.darkBorder : V2Colors.lightBorder;
    final textPrimary =
        isDark ? V2Colors.darkTextPrimary : V2Colors.lightTextPrimary;
    final textSecondary =
        isDark ? V2Colors.darkTextSecondary : V2Colors.lightTextSecondary;

    // Classification is derived strictly from domain's finalStatus
    final isWarning = result.finalStatus == ProgramV2Model.statusWarning;
    final accentColor = isWarning
        ? V2Colors.warmGold
        : (isDark ? V2Colors.pink : const Color(0xFFC53030));

    final statusText = isWarning ? 'Hampir Selesai' : 'Belum Selesai';

    final title = isWarning
        ? 'Amal Istiqomah Minimal Tercapai'
        : 'Evaluasi Muhasabah Selesai';

    final String message;
    if (isWarning) {
      if (result.completedDays != null) {
        message =
            'Alhamdulillah, Anda telah menyelesaikan minimal 40 hari istiqomah (${result.completedDays} hari) sebelum program terhenti. Evaluasi tersimpan dengan aman.';
      } else {
        message =
            'Alhamdulillah, Anda telah menyelesaikan amal istiqomah minimal sebelum program terhenti. Evaluasi tersimpan dengan aman.';
      }
    } else {
      if (result.completedDays != null) {
        message =
            'Catatan evaluasi muhasabah telah tersimpan dengan aman. Perjalanan ibadah (${result.completedDays} hari terselesaikan) dicatat untuk bahan evaluasi diri tanpa mengurangi nilai ikhtiar yang telah dilakukan.';
      } else {
        message =
            'Catatan evaluasi muhasabah telah tersimpan dengan aman untuk bahan evaluasi diri.';
      }
    }

    final reasonLabel = result.failureRecord?.reasonLabelSnapshot ??
        _selectedReason?.label ??
        '-';
    final missedDay = result.failureRecord?.missedDayKey ??
        _currentProgram.pendingMissedDayKey ??
        '-';
    final note = result.failureRecord?.note;

    return SingleChildScrollView(
      key: const ValueKey('v2_muhasabah_completed_view'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(V2Spacing.xl),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: V2Radius.borderLg,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isWarning
                      ? Icons.verified_rounded
                      : Icons.self_improvement_rounded,
                  size: 52,
                  color: accentColor,
                ),
                const SizedBox(height: V2Spacing.md),
                Container(
                  key: const ValueKey('v2_muhasabah_terminal_status'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: V2Spacing.md,
                    vertical: V2Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: V2Radius.borderSm,
                  ),
                  child: Text(
                    statusText,
                    style: V2Typography.bodySmall.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: V2Spacing.md),
                Text(
                  title,
                  style: V2Typography.headingMedium.copyWith(
                    color: textPrimary,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: V2Spacing.sm),
                Text(
                  message,
                  style: V2Typography.bodyMedium.copyWith(
                    color: textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: V2Spacing.lg),
                Divider(color: borderColor),
                const SizedBox(height: V2Spacing.md),

                // Recorded Summary
                _buildSummaryRow(
                  'Nama Program',
                  _currentProgram.ibadahNameSnapshot,
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: V2Spacing.sm),
                _buildSummaryRow(
                  'Alasan Terkendala',
                  reasonLabel,
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: V2Spacing.sm),
                _buildSummaryRow(
                  'Hari Terlewat',
                  _formatMissedDay(missedDay),
                  textPrimary,
                  textSecondary,
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: V2Spacing.sm),
                  _buildSummaryRow(
                    'Catatan',
                    note,
                    textPrimary,
                    textSecondary,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: V2Spacing.lg),

          // Safe explanation about S23 / restart linkage
          Container(
            padding: const EdgeInsets.all(V2Spacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: V2Radius.borderMd,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: textSecondary,
                ),
                const SizedBox(width: V2Spacing.sm),
                Expanded(
                  child: Text(
                    'Catatan evaluasi tersimpan di penyimpanan lokal. Fitur riwayat dan mulai ulang program akan hadir pada pembaruan berikutnya.',
                    style: V2Typography.bodySmall.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: V2Spacing.xl),

          // Return CTA
          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('v2_muhasabah_done_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: V2Colors.warmGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: V2Radius.borderMd,
                ),
              ),
              onPressed: widget.onBackToHub ?? widget.onBack,
              child: const Text(
                'Kembali ke Ibadah Saya',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: V2Spacing.xl),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: V2Typography.bodySmall.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: V2Spacing.xs),
        Expanded(
          child: Text(
            value,
            style: V2Typography.bodySmall.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
