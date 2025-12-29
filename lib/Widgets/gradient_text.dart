
import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.gradient, required this.style});
  final String text;
  final Gradient gradient;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => gradient.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style.copyWith(fontFamily: 'ClashGrotesk')),
    );
  }
}
