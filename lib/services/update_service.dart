import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String githubApiUrl =
      'https://api.github.com/repos/Penguin5681/Code-Keeper/releases/latest';
  static const String githubDownloadUrl =
      'https://github.com/Penguin5681/Code-Keeper/releases/latest/download/code-keeper-windows.zip';

  Future<bool> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final releaseData = json.decode(response.body);
        final latestVersion =
            releaseData['tag_name'].toString().replaceAll('v', '');

        return _compareVersions(currentVersion, latestVersion);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  bool _compareVersions(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<bool> downloadAndInstallUpdate(Function(double) onProgress) async {
    try {
      final response = await http.get(Uri.parse(githubDownloadUrl));

      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        final updateDir = Directory('${appDir.path}\\CodeKeeper\\updates');
        await updateDir.create(recursive: true);

        final zipPath = '${updateDir.path}\\update.zip';
        await File(zipPath).writeAsBytes(response.bodyBytes);

        final result = await Process.run('powershell', [
          '-command',
          "Expand-Archive -Path '$zipPath' -DestinationPath '${updateDir.path}\\extracted' -Force"
        ]);

        if (result.exitCode == 0) {
          final scriptPath = '${updateDir.path}\\update.bat';
          final currentExePath = Platform.resolvedExecutable;
          final updateScript = '''
            @echo off
            timeout /t 2 /nobreak
            del "$currentExePath"
            xcopy /s /y "${updateDir.path}\\extracted\\*" "${path.dirname(currentExePath)}"
            start "" "$currentExePath"
            del /f /q "$scriptPath"
            rmdir /s /q "${updateDir.path}\\extracted"
            del /f /q "$zipPath"
            exit
          ''';
          await File(scriptPath).writeAsString(updateScript);

          await Process.start(scriptPath, [], mode: ProcessStartMode.detached);
          exit(0);
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
