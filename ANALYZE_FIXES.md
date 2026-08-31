# CineNexa v2.1 analyzer fixes

Applied after the Aug 31 Flutter analyzer run:

- Removed the custom `PageTransitionsTheme` block that referenced unavailable `CupertinoPageTransitionsBuilder`; Flutter platform defaults now handle transitions.
- Replaced invalid `Colors.white44` usages with `const Color(0x70FFFFFF)` (44% white).
- Replaced deprecated `.withOpacity(x)` calls with `.withValues(alpha: x)`.
- Cleaned unnecessary multi-underscore callback parameters.
- Removed unnecessary interpolation braces in `movie_repository_factory.dart`.
- Removed the redundant `package:flutter/painting.dart` import from `main.dart`.

The previous user run already showed all tests passing. Re-run `flutter analyze` and `flutter test` on the local Flutter SDK to confirm the analyzer is now clean.
