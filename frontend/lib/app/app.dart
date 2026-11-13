import 'package:flutter/material.dart';

import '../features/authentication/data/trade_square_auth_repository.dart';
import '../features/authentication/presentation/trade_square_auth_flow.dart';
import 'localization/generated/app_localizations.dart';
import 'localization/trade_square_localizations.dart';
import 'theme/app_theme.dart';

class TradeSquareApp extends StatefulWidget {
  const TradeSquareApp({
    this.authRepository,
    super.key,
  });

  final TradeSquareAuthRepository? authRepository;

  @override
  State<TradeSquareApp> createState() => _TradeSquareAppState();
}

class _TradeSquareAppState extends State<TradeSquareApp> {
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light,
      localizationsDelegates: TradeSquareLocalizations.delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TradeSquareAuthFlow(
        authRepository: widget.authRepository,
        onLocaleChanged: (locale) => setState(() => _locale = locale),
      ),
    );
  }
}
