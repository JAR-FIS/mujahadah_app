import 'package:flutter/material.dart';

import '../../../../controllers/v2_dashboard_controller.dart';
import '../../../../theme/v2_design_tokens.dart';

/// Card widget presenting the prayer schedule, countdown, and location for S08 Dashboard.
///
/// Complies with strict data boundaries:
/// - When [schedule] is null, renders an intentional unavailable state without fake times.
/// - When [schedule] is provided, matches the owner-approved Canva S08 layout.
class PrayerScheduleCard extends StatelessWidget {
  final PrayerScheduleData? schedule;
  final VoidCallback? onLocationRefresh;

  const PrayerScheduleCard({
    super.key,
    this.schedule,
    this.onLocationRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nextPrayerName = schedule?.nextPrayerName ?? 'Jadwal Belum Tersedia';
    final nextPrayerTime =
        schedule != null ? 'Pukul ${schedule!.nextPrayerTime}' : 'Pukul --:--';
    final countdown = schedule?.countdownText ?? '--:--:--';
    final locationText = schedule?.locationName ?? 'Lokasi belum diatur';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: V2Spacing.lg),
      padding: const EdgeInsets.all(V2Spacing.lg),
      decoration: BoxDecoration(
        color: V2Colors.deepTosca,
        borderRadius: V2Radius.borderLg,
        boxShadow: isDark ? V2Elevation.darkSubtle : V2Elevation.lightCard,
        border: Border.all(
          color: isDark ? V2Colors.darkBorder : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: Next prayer info, mosque emblem, countdown box
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Next prayer text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Azan berikutnya',
                      style: V2Typography.labelSmall.copyWith(
                        color: V2Colors.mint.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextPrayerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2Typography.headingMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextPrayerTime,
                      style: V2Typography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Center mosque illustration / icon emblem
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: V2Spacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mosque,
                  color: V2Colors.mint,
                  size: 26,
                ),
              ),

              // Countdown badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Spacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: V2Radius.borderMd,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Azan',
                      style: V2Typography.labelSmall.copyWith(
                        color: Colors.white70,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      countdown,
                      style: V2Typography.labelMedium.copyWith(
                        color: V2Colors.peach,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Lagi',
                      style: V2Typography.labelSmall.copyWith(
                        color: Colors.white70,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: V2Spacing.md),

          // Location pill line
          Center(
            child: Semantics(
              label: 'Lokasi: $locationText',
              button: onLocationRefresh != null,
              child: InkWell(
                onTap: onLocationRefresh,
                borderRadius: V2Radius.borderFull,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: V2Spacing.sm,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: V2Colors.peach,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          locationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V2Typography.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.refresh,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: V2Spacing.md),

          // 5 Prayer time pills
          Row(
            children: [
              _buildPrayerPill('Subuh', schedule?.subuh ?? '--:--'),
              const SizedBox(width: 4),
              _buildPrayerPill('Dzuhur', schedule?.dzuhur ?? '--:--'),
              const SizedBox(width: 4),
              _buildPrayerPill('Ashar', schedule?.ashar ?? '--:--'),
              const SizedBox(width: 4),
              _buildPrayerPill('Maghrib', schedule?.maghrib ?? '--:--'),
              const SizedBox(width: 4),
              _buildPrayerPill('Isya', schedule?.isya ?? '--:--'),
            ],
          ),

          if (schedule == null) ...[
            const SizedBox(height: V2Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: V2Spacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: V2Radius.borderSm,
              ),
              child: Text(
                'Jadwal sholat offline akan aktif setelah izin lokasi diatur.',
                style: V2Typography.labelSmall.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrayerPill(String name, String time) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: V2Radius.borderSm,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V2Typography.labelSmall.copyWith(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              maxLines: 1,
              style: V2Typography.labelSmall.copyWith(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
