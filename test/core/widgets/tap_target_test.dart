import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
