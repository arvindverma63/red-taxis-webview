import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/payment_card.dart';

/// Loads the customer's saved payment methods. Card add/remove is stubbed until
/// Revolut tokenisation (B9) lands — the screen surfaces that explicitly.
class PaymentCardsController extends AsyncNotifier<List<PaymentCard>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<List<PaymentCard>> build() => _repo.paymentCards();
}

final paymentCardsProvider =
    AsyncNotifierProvider<PaymentCardsController, List<PaymentCard>>(
  PaymentCardsController.new,
);
