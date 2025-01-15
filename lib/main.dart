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
          content: const Text('Please select a folder first!'),
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
      final projectName = path.basename(selectedPath!);
      final timestamp = DateFormat('dd-MM-yyyy hh-mm-ss a').format(DateTime.now());
      final backupFolderName = '$projectName $timestamp';

      final backupBasePath = path.join(path.dirname(selectedPath!), 'backups');
      final backupPath = path.join(backupBasePath, backupFolderName);

      await Directory(backupBasePath).create(recursive: true);

      await _copyDirectory(selectedPath!, backupPath);

      addLog('Backup created: $backupFolderName');
    } catch (e) {
      addLog('Backup failed: ${e.toString()}');
    }
  }

  Future<void> _copyDirectory(String source, String destination) async {
    await Process.run('powershell', [
      '-command',
      "Copy-Item -Path '$source' -Destination '$destination' -Recurse -Exclude @('node_modules', '.git', 'build')"
    ]);
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
        title: const Text('Project Backup Manager'),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            final result = await FilePicker.platform.getDirectoryPath();
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

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup Interval (minutes)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Start Backup Service'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isBackupRunning ? stopBackup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
