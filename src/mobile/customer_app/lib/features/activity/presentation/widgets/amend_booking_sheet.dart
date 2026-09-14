import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/booking_summary.dart';

/// The result of the amend sheet — a requested new pickup time and/or passenger
/// count. Either field may be unchanged (null = "leave as is").
class AmendRequest {
  const AmendRequest({this.newTime, this.passengers});

  final DateTime? newTime;
  final int? passengers;

  /// True when the customer actually changed something.
  bool get hasChanges => newTime != null || passengers != null;
}

/// Bottom-sheet form to request a change to an active booking: pick a new
/// pickup time and/or adjust passenger count. Pops an [AmendRequest] on submit,
/// or null on dismiss. Shown via [showAppBottomSheet].
class AmendBookingSheet extends StatefulWidget {
  const AmendBookingSheet({super.key, required this.booking});

  final BookingSummary booking;

  @override
  State<AmendBookingSheet> createState() => _AmendBookingSheetState();
}

class _AmendBookingSheetState extends State<AmendBookingSheet> {
  late DateTime _time = widget.booking.scheduledFor;
  late int _passengers = widget.booking.passengers;

  bool get _timeChanged => _time != widget.booking.scheduledFor;
  bool get _passengersChanged => _passengers != widget.booking.passengers;
  bool get _dirty => _timeChanged || _passengersChanged;

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _time.isBefore(now) ? now : _time,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (time == null || !mounted) return;
    setState(() {
      _time = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      AmendRequest(
        newTime: _timeChanged ? _time : null,
        passengers: _passengersChanged ? _passengers : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeader(title: 'Request a change'),
        Text(
          'We’ll send your request to the operator to confirm.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppListTile(
          icon: Icons.schedule,
          title: 'Pickup time',
          subtitle: Fmt.dateTime(_time),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickTime,
        ),
        const SizedBox(height: AppSpacing.sm),
        _PassengerStepper(
          value: _passengers,
          onChanged: (v) => setState(() => _passengers = v),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Send change request',
          icon: Icons.send_outlined,
          onPressed: _dirty ? _submit : null,
        ),
      ],
    );
  }
}

/// A simple +/- stepper for passenger count, bounded 1–8.
class _PassengerStepper extends StatelessWidget {
  const _PassengerStepper({required this.value, required this.onChanged});

  static const _min = 1;
  static const _max = 8;

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: AppStroke.thin,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.group_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('Passengers', style: theme.textTheme.titleMedium),
          ),
          IconButton.outlined(
            onPressed: value > _min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ),
          IconButton.outlined(
            onPressed: value < _max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
