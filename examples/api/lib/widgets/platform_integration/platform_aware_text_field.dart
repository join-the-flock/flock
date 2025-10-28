// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A platform-aware text field that provides consistent behavior across platforms.
///
/// This widget addresses text alignment regressions in CupertinoTextField
/// and ensures consistent UI across iOS and Android.
///
/// Example usage:
/// ```dart
/// PlatformAwareTextField(
///   placeholder: 'Enter your name',
///   onChanged: (value) => print(value),
/// )
/// ```
class PlatformAwareTextField extends StatelessWidget {
  /// Creates a platform-aware text field.
  const PlatformAwareTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.padding = const EdgeInsets.all(6.0),
    this.placeholder,
    this.placeholderStyle,
    this.prefix,
    this.prefixMode = OverlayVisibilityMode.always,
    this.suffix,
    this.suffixMode = OverlayVisibilityMode.always,
    this.clearButtonMode = OverlayVisibilityMode.never,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.dragStartBehavior = DragStartBehavior.start,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints,
    this.restorationId,
    this.enableIMEPersonalizedLearning = true,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// Defines the keyboard focus for this widget.
  final FocusNode? focusNode;

  /// The decoration to show around the text field (Material only).
  final InputDecoration? decoration;

  /// Padding around the text field.
  final EdgeInsetsGeometry padding;

  /// Placeholder text to display when the field is empty.
  final String? placeholder;

  /// The style to use for the placeholder text.
  final TextStyle? placeholderStyle;

  /// A widget to display before the text.
  final Widget? prefix;

  /// When to show the prefix widget.
  final OverlayVisibilityMode prefixMode;

  /// A widget to display after the text.
  final Widget? suffix;

  /// When to show the suffix widget.
  final OverlayVisibilityMode suffixMode;

  /// When to show the clear button.
  final OverlayVisibilityMode clearButtonMode;

  /// The type of keyboard to use for editing the text.
  final TextInputType? keyboardType;

  /// The type of action button to use for the keyboard.
  final TextInputAction? textInputAction;

  /// Configures how the platform keyboard will select an uppercase or lowercase keyboard.
  final TextCapitalization textCapitalization;

  /// The style to use for the text being edited.
  final TextStyle? style;

  /// The strut style to use for the text.
  final StrutStyle? strutStyle;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  /// How the text should be aligned vertically.
  ///
  /// This is particularly important for fixing the CupertinoTextField alignment issue.
  /// Defaults to TextAlignVertical.center for consistent behavior.
  final TextAlignVertical? textAlignVertical;

  /// The directionality of the text.
  final TextDirection? textDirection;

  /// Whether the text field is read-only.
  final bool readOnly;

  /// Whether to show the cursor.
  final bool? showCursor;

  /// Whether this text field should focus itself if nothing else is already focused.
  final bool autofocus;

  /// Character to use for obscuring text.
  final String obscuringCharacter;

  /// Whether to hide the text being edited.
  final bool obscureText;

  /// Whether to enable autocorrection.
  final bool autocorrect;

  /// Whether to show input suggestions.
  final bool enableSuggestions;

  /// The maximum number of lines to show.
  final int? maxLines;

  /// The minimum number of lines to occupy.
  final int? minLines;

  /// Whether the field should expand to fill the parent.
  final bool expands;

  /// The maximum number of characters to allow.
  final int? maxLength;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user indicates they are done editing.
  final VoidCallback? onEditingComplete;

  /// Called when the user submits the text.
  final ValueChanged<String>? onSubmitted;

  /// Input formatters to apply to the text.
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the text field is enabled.
  final bool? enabled;

  /// Width of the cursor.
  final double cursorWidth;

  /// Height of the cursor.
  final double? cursorHeight;

  /// Radius of the cursor corners.
  final Radius? cursorRadius;

  /// Color of the cursor.
  final Color? cursorColor;

  /// The appearance of the keyboard.
  final Brightness? keyboardAppearance;

  /// Padding to add when scrolling to make the text visible.
  final EdgeInsets scrollPadding;

  /// Whether to enable interactive selection.
  final bool enableInteractiveSelection;

  /// Selection controls to use.
  final TextSelectionControls? selectionControls;

  /// How drag start behavior should be handled.
  final DragStartBehavior dragStartBehavior;

  /// Controller for scrolling.
  final ScrollController? scrollController;

  /// Physics for scrolling.
  final ScrollPhysics? scrollPhysics;

  /// Autofill hints for the text field.
  final Iterable<String>? autofillHints;

  /// Restoration ID for state restoration.
  final String? restorationId;

  /// Whether to enable IME personalized learning.
  final bool enableIMEPersonalizedLearning;

  @override
  Widget build(BuildContext context) {
    // Get theme-based defaults
    final ThemeData theme = Theme.of(context);
    final TextStyle defaultStyle = theme.textTheme.bodyLarge ?? const TextStyle();

    // Calculate consistent placeholder style
    final TextStyle effectivePlaceholderStyle = _calculatePlaceholderStyle(
      theme,
      style ?? defaultStyle,
      placeholderStyle,
    );

    // Ensure consistent text alignment
    // This fixes the CupertinoTextField text alignment regression
    final TextAlignVertical effectiveTextAlignVertical =
        textAlignVertical ?? TextAlignVertical.center;

    if (Platform.isIOS || Platform.isMacOS) {
      return CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        padding: padding,
        placeholder: placeholder,
        placeholderStyle: effectivePlaceholderStyle,
        prefix: prefix,
        prefixMode: prefixMode,
        suffix: suffix,
        suffixMode: suffixMode,
        clearButtonMode: clearButtonMode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        style: style ?? defaultStyle,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textAlignVertical: effectiveTextAlignVertical,
        textDirection: textDirection,
        readOnly: readOnly,
        showCursor: showCursor,
        autofocus: autofocus,
        obscuringCharacter: obscuringCharacter,
        obscureText: obscureText,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        maxLines: maxLines,
        minLines: minLines,
        expands: expands,
        maxLength: maxLength,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        enabled: enabled,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
        cursorRadius: cursorRadius ?? const Radius.circular(2.0),
        cursorColor: cursorColor,
        keyboardAppearance: keyboardAppearance,
        scrollPadding: scrollPadding,
        enableInteractiveSelection: enableInteractiveSelection,
        selectionControls: selectionControls,
        dragStartBehavior: dragStartBehavior,
        scrollController: scrollController,
        scrollPhysics: scrollPhysics,
        autofillHints: autofillHints,
        restorationId: restorationId,
        enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      );
    } else {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: decoration ??
            InputDecoration(
              hintText: placeholder,
              hintStyle: effectivePlaceholderStyle,
              contentPadding: padding,
            ),
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        style: style ?? defaultStyle,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textAlignVertical: effectiveTextAlignVertical,
        textDirection: textDirection,
        readOnly: readOnly,
        showCursor: showCursor,
        autofocus: autofocus,
        obscuringCharacter: obscuringCharacter,
        obscureText: obscureText,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        maxLines: maxLines,
        minLines: minLines,
        expands: expands,
        maxLength: maxLength,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        enabled: enabled,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
        cursorRadius: cursorRadius,
        cursorColor: cursorColor,
        keyboardAppearance: keyboardAppearance,
        scrollPadding: scrollPadding,
        enableInteractiveSelection: enableInteractiveSelection,
        selectionControls: selectionControls,
        dragStartBehavior: dragStartBehavior,
        scrollController: scrollController,
        scrollPhysics: scrollPhysics,
        autofillHints: autofillHints,
        restorationId: restorationId,
        enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      );
    }
  }

  /// Calculate consistent placeholder style across platforms.
  ///
  /// This ensures the placeholder has the same font size and height as the
  /// text style, fixing alignment issues.
  TextStyle _calculatePlaceholderStyle(
    ThemeData theme,
    TextStyle textStyle,
    TextStyle? providedPlaceholderStyle,
  ) {
    final TextStyle baseStyle = providedPlaceholderStyle ??
        textStyle.copyWith(
          color: theme.hintColor,
        );

    // Ensure placeholder style matches text style dimensions
    return baseStyle.copyWith(
      fontSize: textStyle.fontSize,
      height: textStyle.height,
      fontFamily: textStyle.fontFamily,
      letterSpacing: textStyle.letterSpacing,
    );
  }
}
