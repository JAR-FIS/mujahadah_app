import 'dart:async';

import '../../models/program_v2_model.dart';

/// Injectable boundary abstraction representing the source of the user's
/// profile recipient name for V2 SUCCESS certification.
///
/// Design & Architectural Invariants:
/// 1. Implementations must return the current verified recipient name if available.
/// 2. Implementations must return `null` if the profile setup has not been completed
///    or is temporarily unavailable.
/// 3. MUST NEVER invent or fabricate fallback names (e.g. "Hamba Allah", "Anonymous").
/// 4. MUST NEVER silently migrate legacy V1 profile data without explicit user consent.
/// 5. Historical recipient snapshots for already-SUCCESS programs are preserved by
///    domain services and are never overwritten by profile changes.
/// 6. Keeps all profile UI and storage concerns strictly outside domain services.
abstract class V2RecipientNameProvider {
  /// Resolves the recipient name snapshot for the given [program] (or general profile if null).
  ///
  /// Returns `null` if the profile recipient name is unavailable, empty, or unconfigured.
  FutureOr<String?> getRecipientName({ProgramV2Model? program});
}

/// Flexible callback-backed implementation of [V2RecipientNameProvider]
/// useful for dependency injection, test doubles, and custom profile resolvers.
class CallbackRecipientNameProvider implements V2RecipientNameProvider {
  final FutureOr<String?> Function({ProgramV2Model? program}) _resolver;

  const CallbackRecipientNameProvider(this._resolver);

  @override
  FutureOr<String?> getRecipientName({ProgramV2Model? program}) =>
      _resolver(program: program);
}

/// Constant provider representing an unconfigured or unavailable user profile.
///
/// Always returns `null`, safely triggering `needsRecipientName` without fabrication
/// and preserving check-in progress until the user completes profile setup.
class UnavailableRecipientNameProvider implements V2RecipientNameProvider {
  const UnavailableRecipientNameProvider();

  @override
  FutureOr<String?> getRecipientName({ProgramV2Model? program}) => null;
}
