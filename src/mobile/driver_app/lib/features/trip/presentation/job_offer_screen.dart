import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/slide_to_accept.dart';
import 'package:driver_app/features/trip/trip.dart';

class JobOfferScreen extends ConsumerStatefulWidget {
  final TripDetails trip;
  const JobOfferScreen({super.key, required this.trip});

  @override
  ConsumerState<JobOfferScreen> createState() => _JobOfferScreenState();
}

class _JobOfferScreenState extends ConsumerState<JobOfferScreen> with SingleTickerProviderStateMixin {
  int _secondsRemaining = 15;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        ref.read(tripProvider.notifier).rejectJob();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCash = widget.trip.paymentType.toLowerCase() == 'cash';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header & Pulsing Timer Section
              Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'NEW BOOKING INCOMING',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryRed.withValues(alpha: 0.8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryRed.withValues(
                                alpha: 0.15 * _pulseController.value,
                              ),
                              blurRadius: 15 * _pulseController.value,
                              spreadRadius: 8 * _pulseController.value,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: CircularProgressIndicator(
                            value: _secondsRemaining / 15.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_secondsRemaining',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textLightPrimary,
                              ),
                            ),
                            const Text(
                              'SEC',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Booking Details ticket-like Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      // Header panel of the ticket
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        color: Colors.grey.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ESTIMATED FARE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '£${widget.trip.fare.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCash 
                                    ? const Color(0xFFE8F5E9) 
                                    : const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: isCash 
                                      ? const Color(0xFFC8E6C9) 
                                      : const Color(0xFFBBDEFB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCash ? Icons.money : Icons.credit_card,
                                    size: 16,
                                    color: isCash 
                                        ? const Color(0xFF2E7D32) 
                                        : const Color(0xFF1565C0),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.trip.paymentType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isCash 
                                          ? const Color(0xFF2E7D32) 
                                          : const Color(0xFF1565C0),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),

                      // Body of the ticket: Route
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      width: 2,
                                      height: 50,
                                      decoration: const BoxDecoration(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.location_on,
                                      color: AppTheme.primaryRed,
                                      size: 20,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PICKUP ADDRESS',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.trip.pickupAddress,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textLightPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      const Text(
                                        'DROPOFF ADDRESS',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.trip.dropoffAddress,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textLightPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            const Divider(color: Color(0xFFF5F5F5)),
                            const SizedBox(height: 8),

                            // Trip Meta Specs (Est Distance & Duration)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildTripMetaItem(Icons.map_outlined, '8.4 miles', 'Distance'),
                                Container(width: 1, height: 24, color: Colors.grey.shade200),
                                _buildTripMetaItem(Icons.schedule_outlined, '22 mins', 'Est. Time'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Interaction Actions
              Column(
                children: [
                  SlideToAccept(
                    onAccept: () {
                      _timer?.cancel();
                      ref.read(tripProvider.notifier).acceptJob();
                    },
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline Job offer'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _timer?.cancel();
                      ref.read(tripProvider.notifier).rejectJob();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripMetaItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textLightPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
