import 'package:flutter/material.dart';

class AppConstants {
  const AppConstants._();

  static const int holidayWeekIndex = 999;
  static const int defaultSemesterTotalWeeks = 18;
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 24;
  static const double sectionGap = 18;
  static const double chipHeight = 64;
  static const double formBottomSafeArea = 96;

  static const EdgeInsets pagePadding = EdgeInsets.all(xxl);
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.symmetric(
    horizontal: xxs,
  );
  static const EdgeInsets floatingSheetPadding = EdgeInsets.fromLTRB(
    xxl,
    sm,
    xxl,
    xxl,
  );
  static const EdgeInsets listPagePadding = EdgeInsets.fromLTRB(
    xl,
    xl,
    xl,
    xxl,
  );
  static const EdgeInsets actionBarPadding = EdgeInsets.fromLTRB(
    xxl,
    lg,
    xxl,
    xxl,
  );
}

class AppRadii {
  const AppRadii._();

  static const double sm = 4;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 18;
  static const double xxl = 22;
  static const double surface = 24;
  static const double pill = 999;
}

class AppDurations {
  const AppDurations._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration switcher = Duration(milliseconds: 220);
  static const Duration pageSync = Duration(milliseconds: 260);
  static const Duration pageJump = Duration(milliseconds: 280);
  static const Duration sheetActionDelay = Duration(milliseconds: 300);
}
