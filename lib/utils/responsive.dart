import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  static double height(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  static double text(BuildContext context, double size) {
    // Assuming standard screen width is around 375
    return size * (MediaQuery.of(context).size.width / 375);
  }

  static double icon(BuildContext context, double size) {
    return size * (MediaQuery.of(context).size.width / 375);
  }

  static double space(BuildContext context, double size) {
    return size * (MediaQuery.of(context).size.height / 812);
  }
}
