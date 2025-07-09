import Cocoa
import FlutterMacOS
import UIKit
import Flutter
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Registrar background tasks
    WorkmanagerPlugin.registerTask(withIdentifier: "ios-background-fetch")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    WorkmanagerPlugin.executeTask(
      with: .backgroundFetch,
      completionHandler: completionHandler
    )
  }
}
