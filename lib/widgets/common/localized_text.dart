import 'package:flutter/material.dart';

/// A text widget that supports localization.
/// Currently a simple pass-through to Text, but will be extended
/// once localization is implemented in the app.
class LocalizedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  
  const LocalizedText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // In the future, this would use a localization lookup
    // For now, just return the text directly
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
} 