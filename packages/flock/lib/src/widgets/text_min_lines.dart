// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui show TextHeightBehavior;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reserves a minimum text height without changing the child's paragraph.
///
/// Used internally by Flock's plain Text widget to keep extra space below the
/// real lines while preserving line breaking, selection, and baselines.
class FlockTextMinLines extends SingleChildRenderObjectWidget {
  /// Creates the internal minimum-line-height wrapper.
  const FlockTextMinLines({
    super.key,
    required this.text,
    required this.textDirection,
    required this.textScaler,
    this.locale,
    this.strutStyle,
    this.textHeightBehavior,
    required super.child,
  });

  /// The empty lines measured using the displayed text's root style.
  final TextSpan text;

  /// The direction used to measure the reserved lines.
  final TextDirection textDirection;

  /// The scaler used by the displayed text.
  final TextScaler textScaler;

  /// The locale used for font selection.
  final Locale? locale;

  /// The strut used by the displayed text.
  final StrutStyle? strutStyle;

  /// The height behavior used by the displayed text.
  final ui.TextHeightBehavior? textHeightBehavior;

  @override
  RenderBox createRenderObject(BuildContext context) {
    return _RenderTextMinLines(
      TextPainter(
        text: text,
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        strutStyle: strutStyle,
        textHeightBehavior: textHeightBehavior,
      ),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderBox renderObject) {
    final minLinesRenderObject = renderObject as _RenderTextMinLines;
    minLinesRenderObject.painter
      ..text = text
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..locale = locale
      ..strutStyle = strutStyle
      ..textHeightBehavior = textHeightBehavior;
    minLinesRenderObject.markNeedsLayout();
  }
}

class _RenderTextMinLines extends RenderProxyBox with RelayoutWhenSystemFontsChangeMixin {
  _RenderTextMinLines(this.painter);

  final TextPainter painter;

  double get _minHeight {
    painter.layout();
    return painter.height;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return math.max(_minHeight, super.computeMinIntrinsicHeight(width));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return math.max(_minHeight, super.computeMaxIntrinsicHeight(width));
  }

  Size _constrainSize(Size childSize, BoxConstraints constraints) {
    return constraints.constrain(Size(childSize.width, math.max(childSize.height, _minHeight)));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _constrainSize(super.computeDryLayout(constraints), constraints);
  }

  @override
  void performLayout() {
    child?.layout(constraints, parentUsesSize: true);
    size = _constrainSize(child?.size ?? Size.zero, constraints);
  }

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    painter.markNeedsLayout();
  }

  @override
  void dispose() {
    painter.dispose();
    super.dispose();
  }
}
