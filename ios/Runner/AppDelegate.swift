import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 注册 Screen Time 监控通道（monitor / intervention）。
    // registrar(forPlugin:) 的参数仅用于取回 messenger，无实际插件同名要求。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenMonitorChannels") {
      ScreenMonitorChannels.register(messenger: registrar.messenger())
    }
  }
}
