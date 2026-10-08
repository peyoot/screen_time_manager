/// 语言控制器：管理系统语言与手动切换。
///
/// 默认值为 `null` 表示跟随系统语言；用户手动切换后记住选择。
/// 持久化存储后续接入（当前内存管理）。
library;

import 'package:flutter/material.dart';

/// 支持的语言列表。
const supportedLocales = [
  Locale('zh'),
  Locale('en'),
  Locale('ja'),
  Locale('ko'),
];

/// 语言控制器。
class LocaleController extends ChangeNotifier {
  Locale? _locale;

  /// 当前生效的语言；`null` 表示跟随系统。
  Locale? get locale => _locale;

  /// 切换语言；传 `null` 恢复跟随系统。
  void setLocale(Locale? locale) {
    _locale = locale;
    notifyListeners();
  }
}
