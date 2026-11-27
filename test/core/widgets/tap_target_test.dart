import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/core/widgets/app_button.dart';
import 'package:survey_contour_generator/src/core/widgets/app_modal.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/analysis/analysis_cards.dart';

Widget _host(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  home: Center(child: child),
);

void main() {
  testWidgets('modal close button is a 44 px target, not just the glyph', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(_host(ModalCloseButton(onClose: () => closed++)));
    final box = tester.getRect(find.byType(ModalCloseButton));
    expect(box.width, greaterThanOrEqualTo(kMinTapTarget));
    expect(box.height, greaterThanOrEqualTo(kMinTapTarget));

    // A thumb landing well off the glyph (the glyph is ~14 px wide).
    await tester.tapAt(box.center + const Offset(18, 16));
    expect(closed, 1);
  });

  testWidgets('expand button is a 44 px target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(ExpandButton(tooltip: 'Expand', onTap: () => taps++)),
    );
    final box = tester.getRect(find.byType(ExpandButton));
    expect(box.width, greaterThanOrEqualTo(kMinTapTarget));
    expect(box.height, greaterThanOrEqualTo(kMinTapTarget));
    await tester.tapAt(box.center + const Offset(-17, 17));
    expect(taps, 1);
  });

  testWidgets('small buttons are 40 px on phone widths, compact on desktop', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpWidget(
      _host(AppButton(small: true, onPressed: () {}, child: const Text('×'))),
    );
    final phone = tester.getSize(find.byType(AppButton));
    expect(phone.height, greaterThanOrEqualTo(40));
    expect(phone.width, greaterThanOrEqualTo(40));

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      _host(AppButton(small: true, onPressed: () {}, child: const Text('×'))),
    );
    await tester.pump(const Duration(milliseconds: 400)); // constraints animate
    expect(tester.getSize(find.byType(AppButton)).height, lessThan(40));
  });
}
