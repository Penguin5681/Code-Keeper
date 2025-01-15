import 'dart:async';
import 'dart:io';

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
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
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
        title: const Text('Code Keeper'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Project Folder',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedPath ?? 'No folder selected',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final result =
                                await FilePicker.platform.getDirectoryPath();
                            if (result != null) {
                              setState(() {
                                selectedPath = result;
                              });
                            }
                          },
                          child: const Text('Select Folder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

// Backup Directory Selection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup Directory',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            backupDirectoryPath ??
                                'No backup directory selected',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final result =
                                await FilePicker.platform.getDirectoryPath();
                            if (result != null) {
                              setState(() {
                                backupDirectoryPath = result;
                              });
                            }
                          },
                          child: const Text('Select Directory'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup Interval (minutes)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter backup interval in minutes',
                      ),
                      onChanged: (value) {
                        setState(() {
                          backupInterval = int.tryParse(value) ?? 5;
                        });
                      },
                      controller: _intervalController,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isBackupRunning ? null : startBackup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Start Backup Service'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isBackupRunning ? stopBackup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Stop Backup Service'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'Backup Logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: backupLogs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        backupLogs[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
