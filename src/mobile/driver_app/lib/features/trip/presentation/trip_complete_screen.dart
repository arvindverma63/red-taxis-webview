import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:driver_app/features/trip/trip.dart';
import 'package:driver_app/features/earnings/earnings.dart';

class TripCompleteScreen extends ConsumerWidget {
  final TripDetails trip;

  const TripCompleteScreen({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCash = trip.paymentType.toLowerCase() == 'cash';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 56.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Checkmark and heading
              Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Trip Complete',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textLightPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Successfully completed trip routing',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),

              // Cash Collection / No Cash Warning Card
              CustomCard(
                child: Column(
                  children: [
                    const Text(
                      'FARE BREAKDOWN',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '£${trip.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payment Method: ${trip.paymentType}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const Divider(height: 40),

                    // Custom styled collection warning banner
                    if (isCash)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money_outlined, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'CASH COLLECTION REQUIRED',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please collect £${trip.fare.toStringAsFixed(2)} directly from the passenger.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.credit_card, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'CARD/ACCOUNT BOOKING',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Payment is handled via Card/Account. Do NOT collect cash from the customer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Return to Dashboard Action (Commit earnings record)
              ElevatedButton(
                onPressed: () {
                  // Save record to daily earnings state
                  ref.read(earningsProvider.notifier).addRecord(
                    EarningRecord(
                      id: trip.id,
                      date: DateTime.now(),
                      amount: trip.fare,
                      tripDescription: 'Pickup: ${trip.pickupAddress}, Dropoff: ${trip.dropoffAddress}',
                    ),
                  );
                  // Finish trip workflow
                  ref.read(tripProvider.notifier).finishShiftItem();
                },
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
