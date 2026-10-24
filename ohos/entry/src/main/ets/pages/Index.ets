import { FlutterPage } from '@ohos/flutter_ohos';

/**
 * 主页面：全量承载 Flutter UI（主页 / 休息页 / 权限引导页等由 Dart 侧路由）。
 */
@Entry
@Component
struct Index {
  build() {
    Stack() {
      FlutterPage()
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
