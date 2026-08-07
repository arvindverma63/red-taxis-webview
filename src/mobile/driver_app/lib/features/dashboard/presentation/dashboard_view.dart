import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:driver_app/features/shift/shift.dart';
import 'package:driver_app/features/earnings/earnings.dart';
import 'package:driver_app/features/trip/trip.dart';

class DriverDashboardView extends ConsumerWidget {
  const DriverDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(shiftProvider);
    final earnings = ref.watch(earningsProvider);
    final isOnline = shift.status == ShiftStatus.online;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Red Taxi Driver Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications feature coming soon.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online / Offline Shift Status Widget
              CustomCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? 'You are On Duty' : 'You are Off Duty',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOnline
                              ? 'Waiting for bookings...'
                              : 'Go online to accept jobs',
                          style: TextStyle(
                            color: isOnline ? Colors.green : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(
                      label: isOnline ? 'ONLINE' : 'OFFLINE',
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Shift Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline ? Colors.grey[800] : null,
                ),
                onPressed: () {
                  if (isOnline) {
                    ref.read(shiftProvider.notifier).goOffline();
                  } else {
                    ref.read(shiftProvider.notifier).goOnline();
                  }
                },
                child: Text(isOnline ? 'Go Offline' : 'Go Online'),
              ),
              const SizedBox(height: 24),

              // Developer Testing Simulation tools (Only visible when driver is online/on duty)
              if (isOnline) ...[
                CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.build_outlined, color: AppTheme.primaryRed, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Developer Simulation Tools',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Simulate an incoming booking request to test layout flows and permissions:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.money, size: 16),
                              label: const Text('Cash Booking', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                ref.read(tripProvider.notifier).offerJob(
                                  const TripDetails(
                                    id: 'sim-cash-booking',
                                    pickupAddress: 'Heathrow Airport Terminal 5',
                                    dropoffAddress: 'Red Taxi Office, London Central',
                                    fare: 45.00,
                                    paymentType: 'Cash',
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.credit_card, size: 16),
                              label: const Text('Card Booking', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                ref.read(tripProvider.notifier).offerJob(
                                  const TripDetails(
                                    id: 'sim-card-booking',
                                    pickupAddress: 'Wembley Stadium Gate A',
                                    dropoffAddress: 'Hilton London Metropole',
                                    fare: 28.50,
                                    paymentType: 'Card',
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Today's Earnings Summary Widget
              const Text(
                'Today\'s Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              CustomCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      icon: Icons.monetization_on_outlined,
                      label: 'Earnings',
                      value: '£${earnings.todayTotal.toStringAsFixed(2)}',
                      color: Colors.green,
                    ),
                    _buildSummaryItem(
                      icon: Icons.directions_car_outlined,
                      label: 'Completed',
                      value: '${earnings.history.length}',
                      color: AppTheme.primaryRed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Trips List
              const Text(
                'Recent Trips',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (earnings.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('No trips completed today.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: earnings.history.length,
                  itemBuilder: (context, index) {
                    final record = earnings.history[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: CustomCard(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.tripDescription,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${record.date.hour}:${record.date.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '£${record.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
