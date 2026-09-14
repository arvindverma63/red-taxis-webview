import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/place.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/saved_addresses_controller.dart';

/// Manage saved addresses (Home / Work / custom). Add via a bottom sheet,
/// delete via the trailing action.
class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(savedAddressesProvider);

    return AppScaffold(
      title: 'Saved addresses',
      body: addresses.when(
        loading: () => const LoadingView(message: 'Loading addresses…'),
        error: (e, _) => ErrorView(
          message: 'Could not load your addresses.',
          onRetry: () => ref.invalidate(savedAddressesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.bookmark_border,
              title: 'No saved addresses',
              subtitle: 'Add your home, work or favourite places for faster '
                  'booking.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final addr = list[i];
              return Dismissible(
                key: ValueKey(addr.id),
                direction: DismissDirection.endToStart,
                background: const _DeleteBackground(),
                confirmDismiss: (_) => _confirmDelete(context, addr),
                onDismissed: (_) =>
                    ref.read(savedAddressesProvider.notifier).remove(addr.id),
                child: AppListTile(
                  icon: _iconFor(addr.label),
                  title: addr.label,
                  subtitle: addr.place.description,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _delete(context, ref, addr),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomBar: AppButton(
        label: 'Add address',
        icon: Icons.add_location_alt_outlined,
        onPressed: () => _showAddSheet(context, ref),
      ),
    );
  }

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l == 'home') return Icons.home_outlined;
    if (l == 'work') return Icons.work_outline;
    return Icons.place_outlined;
  }

  Future<bool> _confirmDelete(BuildContext context, SavedPlace addr) {
    return showConfirmDialog(
      context,
      title: 'Delete address',
      message: 'Remove "${addr.label}" from your saved addresses?',
      confirmLabel: 'Delete',
      destructive: true,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedPlace addr,
  ) async {
    final ok = await _confirmDelete(context, addr);
    if (!ok) return;
    await ref.read(savedAddressesProvider.notifier).remove(addr.id);
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final result = await showAppBottomSheet<SavedPlace>(
      context,
      child: const _AddAddressSheet(),
    );
    if (result != null) {
      await ref.read(savedAddressesProvider.notifier).add(result);
    }
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Icon(Icons.delete_outline, color: scheme.error),
    );
  }
}

/// Bottom sheet to add a saved address. Address is a simple text field for now
/// — full place search lands with the booking address flow.
class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet();

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();
    final saved = SavedPlace(
      id: 'addr_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      place: Place(description: address, addressLine: address),
    );
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Add address'),
          AppTextField(
            controller: _labelController,
            label: 'Label',
            hint: 'Home, Work, Gym…',
            prefixIcon: Icons.label_outline,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a label' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _addressController,
            label: 'Address',
            hint: 'Street, town and postcode',
            prefixIcon: Icons.place_outlined,
            keyboardType: TextInputType.streetAddress,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter an address' : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Save address', onPressed: _save),
        ],
      ),
    );
  }
}
