import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:immich_mobile/i18n/strings.g.dart';
import 'package:immich_mobile/presentation/modules/theme/states/app_theme.state.dart';
import 'package:immich_mobile/presentation/modules/theme/widgets/app_theme_builder.widget.dart';
import 'package:immich_mobile/presentation/router/router.dart';
import 'package:watch_it/watch_it.dart';

class ImmichApp extends StatefulWidget with WatchItStatefulWidgetMixin {
  const ImmichApp({super.key});

  @override
  State createState() => _ImmichAppState();
}

class _ImmichAppState extends State<ImmichApp> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    final router = di<AppRouter>();
    final appTheme = watchIt<AppThemeState>().value;

    return TranslationProvider(
      /// Builder is used to get the sub-context after registering TranslationProvider
      child: Builder(
        builder: (ctx) => AppThemeBuilder(
          theme: appTheme,
          builder: (lightTheme, darkTheme) => MaterialApp.router(
            locale: TranslationProvider.of(ctx).flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: lightTheme,
            darkTheme: darkTheme,
            routerConfig: router.config(),
          ),
        ),
      ),
    );
  }
}
