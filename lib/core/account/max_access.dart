import 'package:flutter_bloc/flutter_bloc.dart';

import 'revenuecat_service.dart';

/// Whether the current customer holds RepSet Max.
class MaxAccessState {
  const MaxAccessState({
    this.isActive = false,
    this.hasResolved = false,
    this.isAvailable = false,
  });

  final bool isActive;

  /// Whether the first lookup has finished. Surfaces that would otherwise
  /// flash an upsell at a subscriber wait for this.
  final bool hasResolved;

  /// Whether this build can sell or verify a subscription at all. Community
  /// builds ship without store keys, so they show no subscription surface.
  final bool isAvailable;

  /// Whether to offer Max right now: possible, known, and not already held.
  bool get shouldOffer => isAvailable && hasResolved && !isActive;
}

/// Tracks the Max entitlement for every surface that needs it.
///
/// Several places ask the same question at once — the home banner, the prompt
/// field, the settings card — so the answer lives in one place rather than
/// being fetched independently by each of them.
///
/// This is a presentation signal. The planner service verifies entitlement on
/// its own before serving AI, because a client can always be made to lie.
class MaxAccessCubit extends Cubit<MaxAccessState> {
  MaxAccessCubit(this._purchases)
    : super(
        MaxAccessState(isAvailable: _purchases?.isConfigured ?? false),
      );

  final RevenueCatService? _purchases;

  Future<void> refresh() async {
    final purchases = _purchases;
    if (purchases == null) {
      emit(const MaxAccessState(hasResolved: true));
      return;
    }
    final active = await purchases.hasMaxAccess();
    if (isClosed) return;
    emit(
      MaxAccessState(
        isActive: active,
        hasResolved: true,
        isAvailable: purchases.isConfigured,
      ),
    );
  }
}
