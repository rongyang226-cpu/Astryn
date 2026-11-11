import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import '../helpers/test_app.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();
  // A transition's first tick reads a frame of the 200 ms fade ahead.
  const firstFrame = 1 / 60 / 0.2;

  Future<void> pumpHome(WidgetTester tester) {
    return tester.pumpWidget(
      HostApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
  }

  testWidgets('a push keeps its whole transition after a long first frame', (
    tester,
  ) async {
    await pumpHome(tester);
    final route = FadePageRoute<void>(builder: (_) => const Text('page'));
    unawaited(navigatorKey.currentState!.push(route));

    await tester.pump();
    expect(find.text('page', skipOffstage: false), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(route.animation!.value, closeTo(firstFrame, 0.01));

    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.value, closeTo(0.5 + firstFrame, 0.01));
  });

  testWidgets('a card page is painted on stage at rest in its first frame', (
    tester,
  ) async {
    await pumpHome(tester);
    final route = CardPageRoute<void>(builder: (_) => const Text('page'));
    unawaited(navigatorKey.currentState!.push(route));

    await tester.pump();
    expect(route.offstage, isFalse);
    expect(route.animation!.value, 0);
    expect(find.text('page'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.value, greaterThan(0));
  });

  FadePageRoute<void> holdingRoute(ValueListenable<bool> ready) {
    return FadePageRoute<void>(
      builder: (_) => ValueListenableBuilder(
        valueListenable: ready,
        builder: (_, ready, _) =>
            ArrivalHold(ready: ready, child: const Text('page')),
      ),
    );
  }

  testWidgets('a push starts while its page is not ready', (tester) async {
    await pumpHome(tester);
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    final route = holdingRoute(ready);
    unawaited(navigatorKey.currentState!.push(route));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(route.animation!.value, closeTo(firstFrame, 0.01));

    ready.value = true;
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.value, closeTo(0.5 + firstFrame, 0.01));
  });

  testWidgets('a card page moves in while its content is still loading', (
    tester,
  ) async {
    await pumpHome(tester);
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    final route = CardPageRoute<void>(
      builder: (_) => ValueListenableBuilder(
        valueListenable: ready,
        builder: (_, ready, _) => ArrivalHold(
          ready: ready,
          child: Text(ready ? 'content' : 'loading'),
        ),
      ),
    );
    unawaited(navigatorKey.currentState!.push(route));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('loading'), findsOneWidget);
    expect(route.animation!.value, greaterThan(0));

    ready.value = true;
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(route.animation!.isCompleted, isTrue);
  });

  testWidgets('a page ready in its first frame does not hold the push', (
    tester,
  ) async {
    await pumpHome(tester);
    final route = holdingRoute(ValueNotifier(true));
    unawaited(navigatorKey.currentState!.push(route));

    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.value, closeTo(0.5 + firstFrame, 0.01));
  });

  testWidgets('a first load slides in with its loading status', (tester) async {
    await pumpHome(tester);
    final loading = ValueNotifier(true);
    addTearDown(loading.dispose);
    final route = FadePageRoute<void>(
      builder: (_) => ValueListenableBuilder(
        valueListenable: loading,
        builder: (_, loading, _) =>
            NullStatusSwitcher(isLoading: loading, child: const Text('page')),
      ),
    );
    unawaited(navigatorKey.currentState!.push(route));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(route.animation!.value, greaterThan(0));

    loading.value = false;
    await tester.pump(Duration.zero);
    expect(find.text('page'), findsOneWidget);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.value, greaterThan(0));
  });

  testWidgets('a bottom sheet starts while its page is not ready', (
    tester,
  ) async {
    await pumpHome(tester);
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    final route = SnapSheetRoute<void>(
      builder: (_, _) => ValueListenableBuilder(
        valueListenable: ready,
        builder: (_, ready, _) =>
            ArrivalHold(ready: ready, child: const Text('sheet')),
      ),
      sheetBarrierColor: const Color(0x42000000),
      barrierLabel: '',
    );
    unawaited(navigatorKey.currentState!.push(route));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(route.animation!.value, greaterThan(0));

    ready.value = true;
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 100));
    expect(route.animation!.value, greaterThan(0));
  });

  testWidgets('a route popped in the frame it was pushed in still leaves', (
    tester,
  ) async {
    await pumpHome(tester);
    final navigator = navigatorKey.currentState!;
    unawaited(
      navigator.push(FadePageRoute<void>(builder: (_) => const Text('page'))),
    );
    navigator.pop();

    await tester.pumpAndSettle();
    expect(find.text('page'), findsNothing);
    expect(navigator.canPop(), isFalse);
  });
}
