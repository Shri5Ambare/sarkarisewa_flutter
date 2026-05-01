// test/widget_test.dart
//
// Lightweight tests that don't require Firebase init. Anything that needs
// Firebase should live under integration_test/ instead — not here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarkarisewa/theme.dart';
import 'package:sarkarisewa/widgets/app_button.dart';
import 'package:sarkarisewa/widgets/empty_state.dart';

void main() {
  group('AppTheme', () {
    test('exposes design-system primary as canonical purple', () {
      expect(AppColors.primary.toARGB32() & 0xFFFFFF, 0x5624D0);
    });

    test('saffron alias points at primary (legacy compat)', () {
      expect(AppColors.saffron, AppColors.primary);
    });

    test('only one border color per design system', () {
      expect(AppColors.borderSoft, AppColors.border);
    });

    test('AppRadius scale mirrors the canonical CSS', () {
      expect(AppRadius.sm,   8);
      expect(AppRadius.md,  10); // inputs
      expect(AppRadius.lg,  12); // buttons
      expect(AppRadius.xl,  14); // nav pills
      expect(AppRadius.xxl, 16); // cards
      expect(AppRadius.xxxl, 20); // sheets / hero
    });

    test('AppShadows.sm/md/lg are flat (no shadow on cards)', () {
      expect(AppShadows.sm, isEmpty);
      expect(AppShadows.md, isEmpty);
      expect(AppShadows.lg, isEmpty);
    });
  });

  group('AppButton', () {
    testWidgets('renders label and triggers onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppButton(
            label: 'Sign In',
            onPressed: () => taps++,
          ),
        ),
      ));

      expect(find.text('Sign In'), findsOneWidget);
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('disabled button does not fire onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppButton(
            label: 'Disabled',
            onPressed: null,
            // also set loading to assert the spinner branch compiles.
            loading: false,
          ),
        ),
      ));
      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });

  group('EmptyState', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'Nothing here',
            message: 'Come back later.',
          ),
        ),
      ));
      expect(find.text('Nothing here'),  findsOneWidget);
      expect(find.text('Come back later.'), findsOneWidget);
    });

    testWidgets('action button fires callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: EmptyState(
            title: 'Offline',
            actionLabel: 'Retry',
            onAction: () => taps++,
          ),
        ),
      ));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
