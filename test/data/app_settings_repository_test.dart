import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/data/repositories/app_settings_repository.dart';
import 'package:screen_time_manager/models/app_settings.dart';

import '_helpers.dart';

void main() {
  late AppSettingsRepository repo;

  setUp(() async {
    final db = await openTestDb();
    repo = AppSettingsRepository(db);
  });

  test('loadOrInit 首次返回 AppSettings.defaults 并写入', () async {
    final s = await repo.loadOrInit();
    expect(s.quizInterval, AppSettings.defaults.quizInterval);
    expect(s.restDuration, AppSettings.defaults.restDuration);
    expect(s.dailyExemptionLimit, 2);

    // 第二次读取应与第一次一致（来自 DB）。
    final s2 = await repo.loadOrInit();
    expect(s2, s);
  });

  test('upsert 覆盖单行配置后 loadOrInit 返回新值', () async {
    await repo.loadOrInit(); // 初始化默认行
    final updated = AppSettings.defaults.copyWith(
      quizInterval: const Duration(minutes: 25),
      restDuration: const Duration(minutes: 7),
      dailyExemptionLimit: 5,
    );
    await repo.upsert(updated);
    final reloaded = await repo.loadOrInit();
    expect(reloaded, updated);
    expect(reloaded.quizInterval, const Duration(minutes: 25));
    expect(reloaded.dailyExemptionLimit, 5);
  });
}
