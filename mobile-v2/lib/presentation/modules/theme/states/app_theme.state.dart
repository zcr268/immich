import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:immich_mobile/domain/models/app_setting.model.dart';
import 'package:immich_mobile/domain/services/app_setting.service.dart';
import 'package:immich_mobile/presentation/modules/theme/utils/colors.dart';

class AppThemeState extends ValueNotifier<AppTheme> {
  final AppSettingService _appSettings;
  StreamSubscription? _appSettingSubscription;

  AppThemeState({required AppSettingService appSettings})
      : _appSettings = appSettings,
        super(AppTheme.blue);

  void init() {
    _appSettingSubscription = _appSettings
        .watchSetting(AppSetting.appTheme)
        .listen((theme) => value = theme);
  }

  @override
  void dispose() {
    _appSettingSubscription?.cancel();
    return super.dispose();
  }
}
