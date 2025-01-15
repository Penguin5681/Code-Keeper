import 'dart:async';
import 'dart:io';

import 'package:code_keeper/services/update_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(const BackupApp());
}

class BackupApp extends StatelessWidget {
  const BackupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Code Keeper',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade400,
          secondary: Colors.tealAccent,
          surface: Colors.grey.shade900,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.grey.shade900,
        ),
      ),
      home: const BackupManager(),
    );
  }
}

class BackupManager extends StatefulWidget {
  const BackupManager({super.key});

  @override
  State<BackupManager> createState() => _BackupManagerState();
}

class _BackupManagerState extends State<BackupManager> {
  String? selectedPath;
  String? backupDirectoryPath;
  int backupInterval = 5;
  bool isBackupRunning = false;
  List<String> backupLogs = [];
  Timer? backupTimer;
  final TextEditingController _intervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _intervalController.text = backupInterval.toString();
  }

  void startBackup() {
    if (selectedPath == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Please select a project folder first!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (backupDirectoryPath == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Please select a backup directory first!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      isBackupRunning = true;
    });

    createBackup();

    backupTimer = Timer.periodic(
      Duration(minutes: backupInterval),
      (timer) => createBackup(),
    );
  }

  void stopBackup() {
    backupTimer?.cancel();
    setState(() {
      isBackupRunning = false;
    });
    addLog('Backup service stopped');
  }

  void createBackup() async {
    try {
      if (backupDirectoryPath == null) {
        addLog('Error: Backup directory not selected');
        return;
      }

      final projectName = path.basename(selectedPath!);
      final timestamp =
          DateFormat('dd-MM-yyyy hh-mm-ss a').format(DateTime.now());
      final backupFolderName = '$projectName $timestamp';

      final backupPath = path.join(backupDirectoryPath!, backupFolderName);

      await Directory(backupDirectoryPath!).create(recursive: true);

      await _copyDirectory(selectedPath!, backupPath);

      addLog('Backup created: $backupFolderName');
    } catch (e) {
      addLog('Backup failed: ${e.toString()}');
    }
  }

  Future<void> _copyDirectory(String source, String destination) async {
    try {
      await Directory(destination).create(recursive: true);

      await for (final entity in Directory(source).list(recursive: false)) {
        final basename = path.basename(entity.path);

        if (entity is Directory) {
          if (['node_modules', '.git', 'build'].contains(basename)) {
            continue;
          }
          await _copyDirectory(
            entity.path,
            path.join(destination, basename),
          );
        } else if (entity is File) {
          await File(entity.path).copy(
            path.join(destination, basename),
          );
        }
      }
    } catch (e) {
      addLog('Error copying directory: ${e.toString()}');
      rethrow;
    }
  }

  void addLog(String message) {
    setState(() {
      backupLogs.insert(0, '${DateTime.now().toString()}: $message');
      if (backupLogs.length > 100) backupLogs.removeLast();
    });
  }

  @override
  void dispose() {
    _intervalController.dispose();
    backupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Code Keeper'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update),
            tooltip: 'Check for Updates',
            onPressed: () async {
              final updateService = UpdateService();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking for updates...'),
                    ],
                  ),
                ),
              );

              final hasUpdate = await updateService.checkForUpdates();
              if (!context.mounted) return;
              Navigator.of(context).pop();
              if (!hasUpdate) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('No Updates Available'),
                    content: const Text('You are running the latest version.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                return;
              }
              if (!context.mounted) return;
              final shouldUpdate = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Update Available'),
                  content: const Text(
                      'A new version is available. Would you like to update now?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Later'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Update Now'),
                    ),
                  ],
                ),
              );
              if (shouldUpdate == true) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Downloading update...'),
                      ],
                    ),
                  ),
                );
                await updateService.downloadAndInstallUpdate((progress) {});
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              // Handle menu actions
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('About'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black87,
              Colors.grey.shade900,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        isBackupRunning ? Icons.backup : Icons.backup_outlined,
                        size: 48,
                        color: isBackupRunning ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isBackupRunning
                            ? 'Backup Service Running'
                            : 'Backup Service Stopped',
                        style: const TextStyle(fontSize: 18),
                      ),
                      if (isBackupRunning) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Next backup in $backupInterval minutes',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Configuration Section
              Expanded(
                child: Card(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: const [
                            Tab(text: 'Configuration'),
                            Tab(text: 'Logs'),
                          ],
                          indicatorColor: Theme.of(context).colorScheme.primary,
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Configuration Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildConfigSection(
                                      'Project Folder',
                                      Icons.folder,
                                      selectedPath ?? 'No folder selected',
                                      () async {
                                        final result = await FilePicker.platform
                                            .getDirectoryPath();
                                        if (result != null) {
                                          setState(() => selectedPath = result);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildConfigSection(
                                      'Backup Directory',
                                      Icons.backup_rounded,
                                      backupDirectoryPath ??
                                          'No backup directory selected',
                                      () async {
                                        final result = await FilePicker.platform
                                            .getDirectoryPath();
                                        if (result != null) {
                                          setState(() =>
                                              backupDirectoryPath = result);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildIntervalSection(),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: isBackupRunning
                                                ? null
                                                : startBackup,
                                            icon: const Icon(Icons.play_arrow),
                                            label: const Text('Start Backup'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              padding: const EdgeInsets.all(16),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: isBackupRunning
                                                ? stopBackup
                                                : null,
                                            icon: const Icon(Icons.stop),
                                            label: const Text('Stop Backup'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              padding: const EdgeInsets.all(16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Logs Tab
                              ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: backupLogs.length,
                                itemBuilder: (context, index) {
                                  final log = backupLogs[index];
                                  final isError = log.contains('Error') ||
                                      log.contains('failed');
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    color: isError
                                        ? Colors.red.withOpacity(0.1)
                                        : null,
                                    child: ListTile(
                                      leading: Icon(
                                        isError
                                            ? Icons.error
                                            : Icons.check_circle,
                                        color:
                                            isError ? Colors.red : Colors.green,
                                      ),
                                      title: Text(
                                        log,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isError
                                              ? Colors.red.shade300
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigSection(
      String title, IconData icon, String value, VoidCallback onSelect) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(color: Colors.grey.shade400),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onSelect,
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer, size: 20),
              SizedBox(width: 8),
              Text('Backup Interval',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _intervalController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter interval in minutes',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade900,
              prefixIcon: const Icon(Icons.schedule),
              suffixText: 'minutes',
            ),
            onChanged: (value) {
              setState(() {
                backupInterval = int.tryParse(value) ?? 5;
              });
            },
          ),
        ],
      ),
    );
  }
}
