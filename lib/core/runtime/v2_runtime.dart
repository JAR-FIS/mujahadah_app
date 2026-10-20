import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../controllers/program_v2_journey_controller.dart';
import '../../models/achievement_model.dart';
import '../../models/daily_checkin_model.dart';
import '../../models/failure_record_model.dart';
import '../../models/program_v2_model.dart';
import '../../repositories/achievement_v2_repository.dart';
import '../../repositories/daily_checkin_v2_repository.dart';
import '../../repositories/failure_record_v2_repository.dart';
import '../../repositories/program_v2_repository.dart';
import '../../services/daily_checkin_v2_service.dart';
import '../../services/program_v2_creation_service.dart';
import '../../services/program_v2_journey_orchestrator.dart';
import '../../services/program_v2_muhasabah_service.dart';
import '../../services/program_v2_reconciliation_service.dart';
import '../../services/program_v2_success_service.dart';
import '../date/date_service.dart';
import 'program_v2_lifecycle_coordinator.dart';
import 'v2_recipient_name_provider.dart';

/// Central V2 Composition Root responsible for:
/// 1. Registering typed V2 Hive adapters idempotently without duplicates.
/// 2. Opening and managing typed V2 Hive boxes with isolated constants.
/// 3. Constructing shared repositories, DateService, and domain services.
/// 4. Assembling the [ProgramV2JourneyOrchestrator].
/// 5. Exposing runtime dependencies for GetX dependency injection.
/// 6. Providing factory methods for [ProgramV2JourneyController] and [ProgramV2LifecycleCoordinator].
class V2Runtime {
  // --- Dedicated V2 Hive Box Name Constants ---
  // Guaranteed distinct from legacy V1 storage ('program', 'user', 'ibadah', 'settings').
  static const String programsBoxName = 'programs_v2';
  static const String dailyCheckInsBoxName = 'daily_checkins_v2';
  static const String failureRecordsBoxName = 'failure_records_v2';
  static const String achievementsBoxName = 'achievements_v2';

  /// List of all V2 box names for validation, auditing, and maintenance.
  static const List<String> allV2BoxNames = [
    programsBoxName,
    dailyCheckInsBoxName,
    failureRecordsBoxName,
    achievementsBoxName,
  ];

  // --- Opened Typed Hive Boxes ---
  final Box<ProgramV2Model> programBox;
  final Box<DailyCheckInModel> checkInBox;
  final Box<FailureRecordModel> failureBox;
  final Box<AchievementModel> achievementBox;

  // --- Repositories ---
  final ProgramV2Repository programRepository;
  final DailyCheckInV2Repository checkInRepository;
  final FailureRecordV2Repository failureRecordRepository;
  final AchievementV2Repository achievementRepository;

  // --- Shared Core & Domain Services ---
  final DateService dateService;
  final ProgramV2CreationService creationService;
  final DailyCheckInV2Service dailyCheckInService;
  final ProgramV2ReconciliationService reconciliationService;
  final ProgramV2MuhasabahService muhasabahService;
  final ProgramV2SuccessService successService;
  final ProgramV2JourneyOrchestrator orchestrator;

  // --- Profile Boundary ---
  final V2RecipientNameProvider? recipientNameProvider;

  V2Runtime._({
    required this.programBox,
    required this.checkInBox,
    required this.failureBox,
    required this.achievementBox,
    required this.programRepository,
    required this.checkInRepository,
    required this.failureRecordRepository,
    required this.achievementRepository,
    required this.dateService,
    required this.creationService,
    required this.dailyCheckInService,
    required this.reconciliationService,
    required this.muhasabahService,
    required this.successService,
    required this.orchestrator,
    this.recipientNameProvider,
  });

  /// Registers all V2 Hive TypeAdapters exactly once.
  ///
  /// Protected by [Hive.isAdapterRegistered] guards to ensure idempotent execution
  /// and prevent duplicate registration exceptions on repeated initialization.
  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(DailyCheckInModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(FailureRecordModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(AchievementModelAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ProgramV2ModelAdapter());
    }
  }

  /// Factory constructor assembling [V2Runtime] from existing open typed boxes.
  ///
  /// Ideal for testing with temporary directories and custom Hive box instances.
  factory V2Runtime.fromBoxes({
    required Box<ProgramV2Model> programBox,
    required Box<DailyCheckInModel> checkInBox,
    required Box<FailureRecordModel> failureBox,
    required Box<AchievementModel> achievementBox,
    DateService? dateService,
    V2RecipientNameProvider? recipientNameProvider,
    String Function()? programIdGenerator,
  }) {
    final sharedDate = dateService ?? DateService();

    final programRepo = ProgramV2Repository(box: programBox);
    final checkInRepo = DailyCheckInV2Repository(box: checkInBox);
    final failureRepo = FailureRecordV2Repository(box: failureBox);
    final achievementRepo = AchievementV2Repository(box: achievementBox);

    final creationSvc = ProgramV2CreationService(
      repository: programRepo,
      dateService: sharedDate,
      idGenerator: programIdGenerator,
    );

    final checkInSvc = DailyCheckInV2Service(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      dateService: sharedDate,
    );

    final reconSvc = ProgramV2ReconciliationService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      dateService: sharedDate,
    );

    final muhasabahSvc = ProgramV2MuhasabahService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      failureRecordRepository: failureRepo,
      dateService: sharedDate,
    );

    final successSvc = ProgramV2SuccessService(
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      achievementRepository: achievementRepo,
      failureRecordRepository: failureRepo,
      dateService: sharedDate,
    );

    final orch = ProgramV2JourneyOrchestrator(
      programRepository: programRepo,
      dailyCheckInService: checkInSvc,
      reconciliationService: reconSvc,
      muhasabahService: muhasabahSvc,
      successService: successSvc,
      dateService: sharedDate,
    );

    return V2Runtime._(
      programBox: programBox,
      checkInBox: checkInBox,
      failureBox: failureBox,
      achievementBox: achievementBox,
      programRepository: programRepo,
      checkInRepository: checkInRepo,
      failureRecordRepository: failureRepo,
      achievementRepository: achievementRepo,
      dateService: sharedDate,
      creationService: creationSvc,
      dailyCheckInService: checkInSvc,
      reconciliationService: reconSvc,
      muhasabahService: muhasabahSvc,
      successService: successSvc,
      orchestrator: orch,
      recipientNameProvider: recipientNameProvider,
    );
  }

  /// Production initialization entry point.
  ///
  /// Registers adapters and opens all dedicated V2 typed boxes.
  static Future<V2Runtime> initialize({
    DateService? dateService,
    V2RecipientNameProvider? recipientNameProvider,
    String Function()? programIdGenerator,
  }) async {
    registerAdapters();

    final pBox = await Hive.openBox<ProgramV2Model>(programsBoxName);
    final cBox = await Hive.openBox<DailyCheckInModel>(dailyCheckInsBoxName);
    final fBox = await Hive.openBox<FailureRecordModel>(failureRecordsBoxName);
    final aBox = await Hive.openBox<AchievementModel>(achievementsBoxName);

    return V2Runtime.fromBoxes(
      programBox: pBox,
      checkInBox: cBox,
      failureBox: fBox,
      achievementBox: aBox,
      dateService: dateService,
      recipientNameProvider: recipientNameProvider,
      programIdGenerator: programIdGenerator,
    );
  }

  /// Installs all V2 repositories, services, and the orchestrator into GetX
  /// for dependency injection in future V2 screens and widgets.
  void installDependencies({bool permanent = true}) {
    if (Get.isRegistered<V2Runtime>()) {
      final existing = Get.find<V2Runtime>();
      if (identical(existing, this)) {
        return;
      }
      throw StateError(
        'A different V2Runtime instance is already installed in GetX. '
        'Cannot install multiple distinct V2Runtime instances.',
      );
    }
    Get.put<DateService>(dateService, permanent: permanent);
    Get.put<ProgramV2Repository>(programRepository, permanent: permanent);
    Get.put<DailyCheckInV2Repository>(checkInRepository, permanent: permanent);
    Get.put<FailureRecordV2Repository>(failureRecordRepository,
        permanent: permanent);
    Get.put<AchievementV2Repository>(achievementRepository,
        permanent: permanent);
    Get.put<ProgramV2CreationService>(creationService, permanent: permanent);
    Get.put<DailyCheckInV2Service>(dailyCheckInService, permanent: permanent);
    Get.put<ProgramV2ReconciliationService>(reconciliationService,
        permanent: permanent);
    Get.put<ProgramV2MuhasabahService>(muhasabahService, permanent: permanent);
    Get.put<ProgramV2SuccessService>(successService, permanent: permanent);
    Get.put<ProgramV2JourneyOrchestrator>(orchestrator, permanent: permanent);
    if (recipientNameProvider != null) {
      Get.put<V2RecipientNameProvider>(recipientNameProvider!,
          permanent: permanent);
    }
    Get.put<V2Runtime>(this, permanent: permanent);
  }

  /// Creates a configured [ProgramV2JourneyController] using this runtime's orchestrator
  /// and recipient name provider.
  ProgramV2JourneyController createJourneyController() {
    return ProgramV2JourneyController(
      orchestrator: orchestrator,
      recipientNameProvider: recipientNameProvider,
      programRepository: programRepository,
    );
  }

  /// Creates a configured [ProgramV2LifecycleCoordinator] using this runtime's orchestrator.
  ProgramV2LifecycleCoordinator createLifecycleCoordinator({
    ProgramV2JourneyController? controller,
    WidgetsBinding? binding,
  }) {
    return ProgramV2LifecycleCoordinator(
      orchestrator: orchestrator,
      controller: controller,
      binding: binding,
    );
  }
}
