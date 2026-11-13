# Frontend

The TradeSquare client is a Flutter/Dart application using Material 3, Riverpod, go_router, and Dio. Platform targets are grouped here; shared application code belongs in `lib/`.

Feature code follows `lib/features/<feature>/{data,domain,presentation}`. Cross-feature primitives live in `lib/core/` or `lib/shared/`, and app-wide routing, theme, and localization live in `lib/app/`.

The initial scaffold does not implement product features. Add licensed Manrope font files under `assets/fonts/` before shipping the configured font family.
