// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontFamily: 'Ahem', fontSize: 10, height: 1);

  Widget host(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: style,
        child: Center(child: child),
      ),
    );
  }

  test('minLines validates the plain Text constructor only', () {
    expect(() => Text('hello', minLines: 0), throwsAssertionError);
    expect(() => Text('hello', minLines: -1), throwsAssertionError);
    expect(() => Text('hello', minLines: 3, maxLines: 2), throwsAssertionError);
    expect(const Text('hello').minLines, isNull);
    expect(const Text.rich(TextSpan(text: 'hello')).minLines, isNull);
  });

  for (final content in <String>['', 'hello', 'one\ntwo', 'one\ntwo\nthree\nfour']) {
    testWidgets('reserves three lines below $content without changing the paragraph', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(Text(content, minLines: 3)));
      final Size size = tester.getSize(find.byType(Text));
      final RenderParagraph paragraph = tester.renderObject(find.byType(RichText));
      expect(size.height, content.contains('four') ? 40 : 30);
      expect(size.width, paragraph.size.width);
      expect(paragraph.text.toPlainText(), content);
      expect(tester.getTopLeft(find.byType(Text)), tester.getTopLeft(find.byType(RichText)));
      expect(
        paragraph.size.height,
        content.contains('four')
            ? 40
            : content.contains('two')
            ? 20
            : 10,
      );
    });
  }

  testWidgets('wraps and truncates normally with minLines and maxLines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 50,
          child: Text(
            'hello hello hello hello',
            minLines: 2,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
    final RenderParagraph paragraph = tester.renderObject(find.byType(RichText));
    expect(tester.getSize(find.byType(Text)), const Size(50, 20));
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(paragraph.text.toPlainText(), 'hello hello hello hello');
    expect(
      paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 5)),
      isNotEmpty,
    );
  });

  testWidgets('grows with wrapping when maxLines is absent', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(const SizedBox(width: 50, child: Text('hello hello hello', minLines: 2))),
    );
    expect(tester.getSize(find.byType(Text)), const Size(50, 30));
  });

  testWidgets('parent height constraints take precedence', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 15),
          child: const Text('hello', minLines: 3),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Text)).height, 15);
    await tester.pumpWidget(host(const SizedBox(height: 50, child: Text('hello', minLines: 3))));
    expect(tester.getSize(find.byType(Text)).height, 50);
  });

  testWidgets('intrinsic height, dry layout, and baselines match layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(const Text('hello', minLines: 3)));
    final RenderBox box = tester.renderObject(find.byType(Text));
    final RenderParagraph paragraph = tester.renderObject(find.byType(RichText));
    const constraints = BoxConstraints(maxWidth: 100);
    expect(box.getMinIntrinsicHeight(100), 30);
    expect(box.getMaxIntrinsicHeight(100), 30);
    expect(box.getDryLayout(constraints), box.size);
    expect(
      box.getDryBaseline(constraints, TextBaseline.alphabetic),
      paragraph.getDryBaseline(constraints, TextBaseline.alphabetic),
    );
    await tester.pumpWidget(host(const IntrinsicHeight(child: Text('hello', minLines: 3))));
    expect(tester.getSize(find.byType(Text)).height, 30);
    await tester.pumpWidget(
      host(
        const Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[Text('hello', minLines: 3), Text('hello')],
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.byType(Text).first).dy,
      tester.getTopLeft(find.byType(Text).last).dy,
    );
  });

  testWidgets('updates and removes the minimum', (WidgetTester tester) async {
    for (final minLines in <int?>[2, 4, 1, null]) {
      await tester.pumpWidget(host(Text('hello', minLines: minLines)));
      expect(tester.getSize(find.byType(Text)).height, (minLines ?? 1) * 10);
    }
  });

  testWidgets('validates the inherited maximum and permits an explicit override', (
    WidgetTester tester,
  ) async {
    Widget limited(int? maxLines) {
      return host(
        DefaultTextStyle(
          style: style,
          maxLines: 1,
          child: Text('hello', minLines: 2, maxLines: maxLines),
        ),
      );
    }

    await tester.pumpWidget(limited(null));
    expect(tester.takeException(), isAssertionError);
    await tester.pumpWidget(limited(3));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Text)).height, 20);
  });

  testWidgets('uses effective typography and updates when it changes', (WidgetTester tester) async {
    for (final fontSize in <double>[10, 20]) {
      for (final applyHeight in <bool>[true, false]) {
        final TextStyle textStyle = style.copyWith(fontSize: fontSize, height: 2);
        final behavior = TextHeightBehavior(
          applyHeightToFirstAscent: applyHeight,
          applyHeightToLastDescent: applyHeight,
        );
        await tester.pumpWidget(
          host(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('hello', minLines: 3, style: textStyle, textHeightBehavior: behavior),
                  Text('\n\n', style: textStyle, textHeightBehavior: behavior),
                ],
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(Text).first).height,
          tester.getSize(find.byType(Text).last).height,
        );
      }
    }
  });

  testWidgets('respects strut, direction, and inherited height behavior', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const DefaultTextHeightBehavior(
          textHeightBehavior: TextHeightBehavior(applyHeightToLastDescent: false),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'hello',
                minLines: 3,
                textDirection: TextDirection.rtl,
                strutStyle: StrutStyle(fontSize: 30, forceStrutHeight: true),
              ),
              Text(
                '\n\n',
                textDirection: TextDirection.rtl,
                strutStyle: StrutStyle(fontSize: 30, forceStrutHeight: true),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(Text).first).height,
      tester.getSize(find.byType(Text).last).height,
    );
  });

  testWidgets('preserves semantics labels and selection content', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    SelectedContent? selectedContent;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SelectionArea(
            onSelectionChanged: (SelectedContent? content) => selectedContent = content,
            child: const Text('hello', minLines: 3, semanticsLabel: 'greeting', style: style),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Text)).height, 30);
    expect(find.bySemanticsLabel('greeting'), findsOneWidget);
    final RenderParagraph paragraph = tester.renderObject(find.byType(RichText).last);
    expect(paragraph.text.toPlainText(), 'hello');
    expect(paragraph.getPositionForOffset(const Offset(0, 29)).offset, lessThanOrEqualTo(5));
    await tester.longPress(find.byType(RichText).last);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(selectedContent?.plainText, 'hello');
    handle.dispose();
  });
}
