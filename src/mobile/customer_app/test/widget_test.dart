import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/app.dart';

void main() {
  testWidgets('App boots without error and mounts the router', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));
    await tester.pump(); // splash frame

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
