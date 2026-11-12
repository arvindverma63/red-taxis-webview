import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/domain/auth_user.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/profile_controller.dart';

/// Edit the signed-in customer's name, phone and photo via the customer API
/// (`/api/v2/customers/me/profile` and `/api/v2/customers/me/photo`). Email is
/// shown read-only.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _seed(AuthUser user) {
    if (_seeded) return;
    _seeded = true;
    _name.text = user.fullName;
    _phone.text = user.phoneNumber ?? '';
    _email.text = user.email ?? '';
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String _messageFor(Object e, String fallback) =>
      e is ApiException ? e.message : fallback;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Please enter your name.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(profileControllerProvider.notifier)
          .save(fullName: name, phoneNumber: _phone.text.trim());
      if (!mounted) return;
      _toast('Profile updated.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(_messageFor(e, 'Could not save your profile.'));
    }
  }

  Future<void> _changePhoto(bool hasPhoto) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final controller = ref.read(profileControllerProvider.notifier);
    setState(() => _photoBusy = true);
    try {
      if (choice == 'remove') {
        await controller.removePhoto();
      } else {
        final file = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (file == null) return;
        await controller.uploadPhoto(file.path);
      }
    } catch (e) {
      if (mounted) _toast(_messageFor(e, 'Could not update your photo.'));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider);
    final user = profile.valueOrNull;

    return AppScaffold(
      title: 'Edit profile',
      body: user == null
          ? profile.hasError
              ? ErrorView(
                  message: 'Could not load your profile.',
                  onRetry: () => ref.invalidate(profileControllerProvider),
                )
              : const LoadingView()
          : _form(context, user),
    );
  }

  Widget _form(BuildContext context, AuthUser user) {
    _seed(user);
    final hasPhoto = (user.photoUrl ?? '').isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        Center(
          child: GestureDetector(
            onTap: _photoBusy ? null : () => _changePhoto(hasPhoto),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppAvatar(
                  name: user.fullName,
                  imageUrl: user.photoUrl,
                  size: 104,
                ),
                if (_photoBusy)
                  const SizedBox(
                    width: 104,
                    height: 104,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.edit, size: 16, color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          controller: _name,
          label: 'Full name',
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          enabled: !_saving,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _phone,
          label: 'Phone number',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          textInputAction: TextInputAction.done,
          enabled: !_saving,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _email,
          label: 'Email',
          prefixIcon: Icons.mail_outline,
          enabled: false,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: 'Save changes', isLoading: _saving, onPressed: _save),
      ],
    );
  }
}
