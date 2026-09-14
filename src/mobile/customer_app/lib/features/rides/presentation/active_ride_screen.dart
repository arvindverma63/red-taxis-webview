import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/rides_notifier.dart';

class ActiveRideScreen extends ConsumerWidget {
  const ActiveRideScreen({super.key});

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesState = ref.watch(ridesProvider);
    final ride = ridesState.currentActiveRide;
    final branding = ref.watch(tenantBrandingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Tracking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_filled_outlined, size: 60, color: branding.primaryColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text('No Active Trip', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('You do not have any live taxi requests right now.', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Book a Ride'),
              ),
            ],
          ),
        ),
      );
    }

    String statusTitle;
    String statusSubtitle;
    if (ride.status == 'driver_allocated') {
      statusTitle = 'Driver En Route';
      statusSubtitle = 'Arriving in ~${ridesState.etaMinutes} mins';
    } else if (ride.status == 'arrived') {
      statusTitle = 'Driver Has Arrived!';
      statusSubtitle = 'Your taxi is waiting outside pickup location';
    } else if (ride.status == 'on_trip') {
      statusTitle = 'On Trip to Destination';
      statusSubtitle = 'Estimated arrival in ~${ridesState.etaMinutes} mins';
    } else {
      statusTitle = 'Requesting Dispatch';
      statusSubtitle = 'Locating the nearest available driver';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Status & Tracking'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live Simulated Map Area
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                child: Stack(
                  children: [
                    // Stylized GPS grid background
                    Positioned.fill(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: branding.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: branding.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6),
                                ],
                              ),
                              child: Text(
                                '${ridesState.etaMinutes} mins away',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Floating Status Banner
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    statusTitle,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    statusSubtitle,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: ride.status),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Driver & Trip Information Sheet
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Driver details row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: branding.primaryColor.withOpacity(0.15),
                        child: Text(
                          ride.driverName?.substring(0, 1) ?? 'D',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: branding.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.driverName ?? 'Assigned Driver',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              ride.vehicleModel ?? '${ride.vehicleType} Class',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      // UK License Plate Box
                      if (ride.vehicleReg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD100),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black45),
                          ),
                          child: Text(
                            ride.vehicleReg!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.2,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (ride.driverPhone != null) _makeCall(ride.driverPhone!);
                          },
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call Driver'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (branding.dispatchPhone != null) _makeCall(branding.dispatchPhone!);
                          },
                          icon: const Icon(Icons.support_agent_rounded, size: 18),
                          label: const Text('Call Office'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Cancel / Amend Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancel Ride?'),
                            content: const Text('Are you sure you want to cancel this booking? There is no fee if cancelled before driver arrival.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Ride')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref.read(ridesProvider.notifier).cancelRide(ride.id);
                                },
                                child: const Text('Cancel Booking', style: TextStyle(color: Color(0xFFEF4444))),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Cancel Booking', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
