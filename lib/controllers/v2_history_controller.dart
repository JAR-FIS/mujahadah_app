import 'package:get/get.dart';

import '../models/failure_record_model.dart';
import '../models/program_v2_model.dart';
import '../repositories/failure_record_v2_repository.dart';
import '../repositories/program_v2_repository.dart';
import '../services/daily_checkin_v2_service.dart';

/// Available filter categories for the V2 History screen.
enum HistoryFilter {
  all,
  success,
  warning,
  failed;

  String get label {
    switch (this) {
      case HistoryFilter.all:
        return 'Semua';
      case HistoryFilter.success:
        return 'Selesai';
      case HistoryFilter.warning:
        return 'Hampir Selesai';
      case HistoryFilter.failed:
        return 'Belum Selesai';
    }
  }
}

/// Controller managing History state, filtering, progress snapshots, and failure records.
///
/// Responsibilities:
/// 1. Queries and projects terminal programs (SUCCESS, WARNING, FAILED) exclusively.
/// 2. Filters OUT any active or pending-failure programs prior to presentation.
/// 3. Orders items deterministically newest-first by finalizedAt (fallback updatedAt),
///    using program ID as a stable tie-break.
/// 4. Provides badge counts strictly derived from stored terminal data.
/// 5. Asynchronously fetches authoritative progress and failure record snapshots.
/// 6. Safely handles storage read failures with transparent loading and error states.
class V2HistoryController extends GetxController {
  final ProgramV2Repository? _programRepository;
  final FailureRecordV2Repository? _failureRecordRepository;
  final DailyCheckInV2Service? _dailyCheckInService;

  final Rx<HistoryFilter> _selectedFilter = HistoryFilter.all.obs;
  final RxList<ProgramV2Model> _allTerminalPrograms = <ProgramV2Model>[].obs;
  final Rxn<ProgramV2Model> _selectedProgram = Rxn<ProgramV2Model>();
  final RxBool _isLoading = false.obs;
  final RxnString _errorMessage = RxnString();

  // Cached authoritative progress snapshots per programId
  final RxMap<String, ProgramProgressSnapshot> _progressCache =
      <String, ProgramProgressSnapshot>{}.obs;

  // Cached verified failure records per programId
  final RxMap<String, FailureRecordModel> _failureRecordCache =
      <String, FailureRecordModel>{}.obs;

  V2HistoryController({
    ProgramV2Repository? programRepository,
    FailureRecordV2Repository? failureRecordRepository,
    DailyCheckInV2Service? dailyCheckInService,
  })  : _programRepository = programRepository,
        _failureRecordRepository = failureRecordRepository,
        _dailyCheckInService = dailyCheckInService {
    loadHistory();
  }

  /// Currently selected filter category.
  HistoryFilter get selectedFilter => _selectedFilter.value;

  /// Currently selected program for detail view, or null if on history list.
  ProgramV2Model? get selectedProgram => _selectedProgram.value;

  /// Whether history data is currently being loaded.
  bool get isLoading => _isLoading.value;

  /// Error message from read failure, if any.
  String? get errorMessage => _errorMessage.value;

  /// Whether detail view is open.
  bool get isDetailOpen => _selectedProgram.value != null;

  /// Total count of all terminal programs.
  int get countAll => _allTerminalPrograms.length;

  /// Count of completed programs (SUCCESS).
  int get countSuccess => _allTerminalPrograms
      .where((p) => p.status == ProgramV2Model.statusSuccess)
      .length;

  /// Count of nearly completed programs (WARNING).
  int get countWarning => _allTerminalPrograms
      .where((p) => p.status == ProgramV2Model.statusWarning)
      .length;

  /// Count of interrupted programs (FAILED).
  int get countFailed => _allTerminalPrograms
      .where((p) => p.status == ProgramV2Model.statusFailed)
      .length;

  /// All terminal programs matching the current [selectedFilter], ordered newest-first.
  List<ProgramV2Model> get filteredPrograms {
    final list = _allTerminalPrograms.where((p) {
      switch (_selectedFilter.value) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.success:
          return p.status == ProgramV2Model.statusSuccess;
        case HistoryFilter.warning:
          return p.status == ProgramV2Model.statusWarning;
        case HistoryFilter.failed:
          return p.status == ProgramV2Model.statusFailed;
      }
    }).toList();

    list.sort(_compareTerminalPrograms);
    return list;
  }

  /// Selects a filter category.
  void selectFilter(HistoryFilter filter) {
    _selectedFilter.value = filter;
  }

  /// Opens the detail view for [program].
  void selectProgram(ProgramV2Model program) {
    _selectedProgram.value = program;
    _fetchDetailAsync(program, _loadGeneration);
  }

  /// Closes the detail view and returns to the list.
  void clearSelectedProgram() {
    _selectedProgram.value = null;
  }

  /// Retrieves cached progress for [programId], if already loaded.
  ProgramProgressSnapshot? getCachedProgress(String programId) {
    return _progressCache[programId];
  }

  /// Retrieves cached failure record for [programId], if already loaded.
  FailureRecordModel? getCachedFailureRecord(String programId) {
    return _failureRecordCache[programId];
  }

  int _loadGeneration = 0;

  /// Loads or reloads terminal programs from storage.
  ///
  /// Set [silent] to `true` during background tab re-entry to prevent flickering
  /// a full loading indicator when items are already rendered.
  Future<void> loadHistory({bool silent = false}) async {
    final repo = _programRepository;
    if (repo == null) {
      _allTerminalPrograms.clear();
      _isLoading.value = false;
      return;
    }

    final currentGen = ++_loadGeneration;

    try {
      if (!silent || _allTerminalPrograms.isEmpty) {
        _isLoading.value = true;
      }
      _errorMessage.value = null;

      final all = repo.getAll();
      final terminalOnly = all.where((p) {
        return p.status == ProgramV2Model.statusSuccess ||
            p.status == ProgramV2Model.statusWarning ||
            p.status == ProgramV2Model.statusFailed;
      }).toList();

      terminalOnly.sort(_compareTerminalPrograms);

      if (currentGen != _loadGeneration) return;
      _allTerminalPrograms.assignAll(terminalOnly);

      // Keep selectedProgram synchronized if detail is open
      if (_selectedProgram.value != null) {
        final currentSelectedId = _selectedProgram.value!.id;
        final refreshed =
            terminalOnly.firstWhereOrNull((p) => p.id == currentSelectedId);
        if (refreshed != null) {
          _selectedProgram.value = refreshed;
        }
      }

      // Populate or refresh caches for visible items with generation safety
      await _populateCachesAsync(terminalOnly, currentGen);
    } catch (_) {
      if (currentGen == _loadGeneration) {
        _errorMessage.value =
            'Gagal memuat data riwayat mujahadah. Silakan coba lagi.';
      }
    } finally {
      if (currentGen == _loadGeneration) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _populateCachesAsync(
      List<ProgramV2Model> programs, int generation) async {
    for (final p in programs) {
      if (generation != _loadGeneration) return;
      await _fetchDetailAsync(p, generation);
    }
  }

  Future<void> _fetchDetailAsync(ProgramV2Model program, int generation) async {
    // 1. Fetch progress snapshot if service available
    if (_dailyCheckInService != null) {
      try {
        final progress = await _dailyCheckInService!.getProgress(program.id);
        if (generation == _loadGeneration && progress != null) {
          _progressCache[program.id] = progress;
        }
      } catch (_) {
        // Fallback gracefully without throwing
      }
    }

    // 2. Fetch failure record for FAILED / WARNING programs
    if (_failureRecordRepository != null) {
      if (program.status == ProgramV2Model.statusFailed ||
          program.status == ProgramV2Model.statusWarning) {
        try {
          FailureRecordModel? record;
          if (program.pendingMissedDayKey != null &&
              program.pendingMissedDayKey!.isNotEmpty) {
            record = _failureRecordRepository!.getByProgramAndMissedDay(
              program.id,
              program.pendingMissedDayKey!,
            );
          }
          record ??=
              _failureRecordRepository!.getByProgramId(program.id).firstOrNull;

          if (generation == _loadGeneration && record != null) {
            _failureRecordCache[program.id] = record;
          }
        } catch (_) {
          // Fallback gracefully without throwing
        }
      }
    }
  }

  @override
  void onClose() {
    _loadGeneration++;
    super.onClose();
  }

  /// Deterministic newest-first comparison with ID tie-break.
  static int _compareTerminalPrograms(ProgramV2Model a, ProgramV2Model b) {
    final timeA = a.finalizedAt ?? a.updatedAt;
    final timeB = b.finalizedAt ?? b.updatedAt;
    final timeComp = timeB.compareTo(timeA);
    if (timeComp != 0) return timeComp;
    return b.id.compareTo(a.id);
  }
}
