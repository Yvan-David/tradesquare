import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/app_localizations.dart';

abstract final class TradeSquareLocalizations {
  static const delegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    _KinyarwandaMaterialLocalizationsDelegate(),
    _KinyarwandaCupertinoLocalizationsDelegate(),
    _KinyarwandaWidgetsLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];
}

class _KinyarwandaMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _KinyarwandaMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'rw' ||
      (locale.languageCode == 'sw' &&
          !GlobalMaterialLocalizations.delegate.isSupported(locale));

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_KinyarwandaMaterialLocalizationsDelegate old) => false;
}

class _KinyarwandaCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KinyarwandaCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'rw' ||
      (locale.languageCode == 'sw' &&
          !GlobalCupertinoLocalizations.delegate.isSupported(locale));

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_KinyarwandaCupertinoLocalizationsDelegate old) => false;
}

class _KinyarwandaWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _KinyarwandaWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'rw' ||
      (locale.languageCode == 'sw' &&
          !GlobalWidgetsLocalizations.delegate.isSupported(locale));

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_KinyarwandaWidgetsLocalizationsDelegate old) => false;
}
