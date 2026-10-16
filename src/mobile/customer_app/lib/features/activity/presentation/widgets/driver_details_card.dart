import 'package:flutter/material.dart';

import '../../../../core/domain/driver_directory.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/phone_launcher.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/booking_summary.dart';

/// "Your driver" card for the booking details page: the assigned driver's name,
/// rating, vehicle, number plate and phone, with call / message actions.
///
/// Renders nothing until a driver has been assigned (details come from the
/// [DriverDirectory], filled in as bookings load).
class DriverDetailsCard extends StatelessWidget {
  const DriverDetailsCard({super.key, required this.booking});

  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final driver = DriverDirectory.of(booking.id);
    if (driver == null || !driver.hasName) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final name = driver.name!.trim();
    final phone = (driver.phone ?? '').trim();
    final plate = (driver.plate ?? '').trim();
    final vehicle = driver.vehicleDescription.isNotEmpty
        ? driver.vehicleDescription
        : booking.vehicleName;
    final rating = driver.rating;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your driver', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppAvatar(name: name, imageUrl: driver.photoUrl, size: 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rating != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            rating.toStringAsFixed(1),
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.local_taxi_outlined,
            label: 'Vehicle',
            value: vehicle,
          ),
          if (plate.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.pin_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Number plate', style: theme.textTheme.bodySmall),
                const Spacer(),
                _PlateBadge(plate: plate),
              ],
            ),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => callDriver(context, phone, name),
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => messageDriver(context, phone, name),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// UK-style number plate: yellow rear plate with black monospaced lettering.
class _PlateBadge extends StatelessWidget {
  const _PlateBadge({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7D117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black87, width: 1.2),
      ),
      child: Text(
        plate.toUpperCase(),
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontSize: 14,
        ),
      ),
    );
  }
}
