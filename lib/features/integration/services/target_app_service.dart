import '../../guard/services/app_whitelist_service.dart';

class TargetAppStatus {
  const TargetAppStatus({
    required this.packageName,
    required this.label,
    required this.installed,
  });

  final String packageName;
  final String label;
  final bool installed;
}

class TargetAppService {
  const TargetAppService();

  Future<TargetAppStatus> inspect({
    required String packageName,
    required String fallbackLabel,
  }) async {
    final apps = await const AppWhitelistService().listApps();
    for (final app in apps) {
      if (app.packageName == packageName) {
        return TargetAppStatus(
          packageName: packageName,
          label: app.label,
          installed: true,
        );
      }
    }
    return TargetAppStatus(
      packageName: packageName,
      label: fallbackLabel,
      installed: false,
    );
  }

  Future<bool> launch(String packageName) =>
      const AppWhitelistService().launchApp(packageName);
}
