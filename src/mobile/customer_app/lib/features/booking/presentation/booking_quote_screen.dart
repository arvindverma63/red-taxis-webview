import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../application/booking_notifier.dart';
import '../domain/booking_models.dart';

class BookingQuoteScreen extends ConsumerWidget {
  const BookingQuoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);
    final branding = ref.watch(tenantBrandingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Ride & Fare'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route Timeline Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PICKUP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                    Text(
                                      state.pickupAddress.isNotEmpty ? state.pickupAddress : 'Current Location',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Container(width: 2, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ],
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.location_on_rounded, size: 18, color: branding.primaryColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('DROPOFF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                    Text(
                                      state.dropoffAddress.isNotEmpty ? state.dropoffAddress : 'Airport Terminal 2',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Tier Selection
                    Text(
                      'Select Vehicle',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...VehicleOption.defaultOptions.map((v) {
                      final isSelected = state.selectedVehicle.type == v.type;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => notifier.selectVehicle(v),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? branding.primaryColor.withOpacity(0.15) : branding.primaryColor.withOpacity(0.06))
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? branding.primaryColor
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                width: isSelected ? 2 : 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? branding.primaryColor.withOpacity(0.15)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(v.icon, size: 24, color: isSelected ? branding.primaryColor : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? branding.primaryColor : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          const SizedBox(width: 2),
                                          Text('${v.capacity}', style: const TextStyle(fontSize: 12)),
                                          const SizedBox(width: 10),
                                          Icon(Icons.luggage_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          const SizedBox(width: 2),
                                          Text('${v.luggageCapacity}', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '£${v.basePrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? branding.primaryColor : null,
                                      ),
                                    ),
                                    const Text('Estimated', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Passengers and Luggage counter controls
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Passengers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => notifier.setPassengers(state.passengers - 1),
                                      child: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('${state.passengers}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    InkWell(
                                      onTap: () => notifier.setPassengers(state.passengers + 1),
                                      child: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Luggage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => notifier.setLuggage(state.luggage - 1),
                                      child: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('${state.luggage}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    InkWell(
                                      onTap: () => notifier.setLuggage(state.luggage + 1),
                                      child: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Payment method selection
                    Text(
                      'Payment Method',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildPaymentChip(context, ref, 'Cash', 'cash', Icons.payments_rounded, state.paymentMethod == 'cash'),
                        const SizedBox(width: 8),
                        _buildPaymentChip(context, ref, 'Card / Pay', 'card', Icons.credit_card_rounded, state.paymentMethod == 'card'),
                        const SizedBox(width: 8),
                        _buildPaymentChip(context, ref, 'Account', 'account', Icons.account_balance_rounded, state.paymentMethod == 'account'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Book Taxi Confirmation Dock
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total Estimated Fare', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(
                        '£${(state.quote?.fare ?? state.selectedVehicle.basePrice).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: branding.primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: AppButton(
                      text: 'Request Ride',
                      isLoading: state.isSubmitting,
                      onPressed: () async {
                        final booking = await notifier.createBooking();
                        if (booking != null && context.mounted) {
                          context.push('/booking/confirm');
                        }
                      },
                      branding: branding,
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

  Widget _buildPaymentChip(BuildContext context, WidgetRef ref, String label, String value, IconData icon, bool isSelected) {
    final branding = ref.watch(tenantBrandingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(bookingProvider.notifier).setPaymentMethod(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? branding.primaryColor.withOpacity(0.12)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? branding.primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? branding.primaryColor : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? branding.primaryColor : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
