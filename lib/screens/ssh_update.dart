import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:sailogger719/constant/colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:sailogger719/screens/home_screen.dart';
import 'package:wifi_iot/wifi_iot.dart';

class SSHCommandExecutor {
  final String host;
  final int port;
  final String username;
  final String password;

  SSHCommandExecutor({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });
}

class SSHFileTransferScreen extends StatefulWidget {
  @override
  _SSHFileTransferScreenState createState() => _SSHFileTransferScreenState();
}

class _SSHFileTransferScreenState extends State<SSHFileTransferScreen> {
  final String host = '172.24.1.1';
  final int port = 22;
  final String username = 'skyflix';
  final String password = 'byskyreach';
  final Dio _dio = Dio();
  bool is_download = false;
  bool is_install = false;
  bool is_transfer = false;
  bool is_checkwifi = true;
  bool is_unzip = false;
  bool error_download = false;
  bool install_completed = false;
  bool is_error_cmd = false;
  double status_download = 0.0;
  bool install_satisfied = false;
  List<String> _commands = [];
  String _filePath = '';
  String? _ssid = "";
  Timer? ssidCheckTimer;
  String _url = "https://navigatorplus.sailink.id/";
  String down_link = 'sources/SAILOGGER-NEO-7.19.zip';
  String down_filename = 'SAILOGGER-NEO-7.19.zip';
  String _filePath_server = '/home/skyflix/SAILOGGER-NEO-7.19.zip';
  String remoteZipFile = '/home/skyflix/SAILOGGER-NEO-7.19.zip';
  String destinationzipPath = '/home/skyflix/';
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );
  String _versionPath = '/var/Python/Version';
  final ValueNotifier<String> _progressNotifier = ValueNotifier<String>("");

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  void fetchCommands() async {
    setState(() {
      _commands.clear();
    });
    try {
      // Make the GET request
      final response =
          await http.get(Uri.parse(_url + 'api/sailogger/device/version'));

      // Check if the request was successful
      if (response.statusCode == 200) {
        // Decode the JSON data
        final List<dynamic> jsonData = jsonDecode(response.body);

        for (var item in jsonData) {
          if (item['sources'] != null &&
              item['name'].toString().toUpperCase().contains('SAILOGGER-NEO')) {
            for (var source in item['sources']) {
              if (source['commands'] != null) {
                setState(() {
                  _commands.addAll(List<String>.from(source['commands']));
                });
              }
            }
          }
        }

        print('Install Commands: $_commands');
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void onUploadError() {
    setState(() {
      is_install = false;
    });
  }

  void onCommandError() {
    setState(() {
      is_error_cmd = true;
    });
  }

  void getCurrentWifiSSID() async {
    setState(() {
      _ssid = 'Loading...';
    });
    try {
      // Check if Wi-Fi is enabled
      final isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isWifiEnabled) {
        print("Wi-Fi is not enabled.");
        setState(() {
          _ssid = 'Wi-Fi is not enabled';
        });
      }

      // Fetch the current Wi-Fi SSID
      String? ssid = await WiFiForIoTPlugin.getSSID();
      if (ssid != null && ssid.isNotEmpty) {
        print("Current Wi-Fi SSID: $ssid");
        setState(() {
          _ssid = ssid;
        });
        // Return the SSID as a string
      } else {
        setState(() {
          _ssid = "No Wi-Fi Connected";
        });
        print("No Wi-Fi connected.");
      }
    } catch (e) {
      print("Error fetching SSID: $e");
      setState(() {
        _ssid = "Error";
      });
    }
  }

  Future<void> checkAndDeleteFile() async {
    try {
      // Create an SSH client
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      // Run a command to check if the file exists
      final checkResult = await client
          .run('test -f $_filePath_server && echo "exists" || echo "notfound"');
      final checkOutput =
          utf8.decode(checkResult); // Convert Uint8List to String

      if (checkOutput.trim() == "exists") {
        print("File exists at $_filePath_server. Deleting...");
        // Run a command to delete the file
        final deleteResult = await client.run('rm $_filePath_server');
        final deleteOutput = utf8.decode(deleteResult);

        if (deleteOutput.isEmpty) {
          print("File successfully deleted.");
        } else {
          print("Error during deletion: $deleteOutput");
        }
      } else {
        print("File does not exist at $_filePath_server.");
      }

      // Close the SSH client
      client.close();

      compareRemoteFileContent();
    } catch (e) {
      print("An error occurred: $e");
    }
  }

  Future<void> runCommands() async {
    try {
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      try {
        for (var command in _commands) {
          print('Running command: $command');
          var result = await client.run(command);
          print('Result: $result');
        }
      } catch (e) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          backgroundColor: slapp_color.error,
          content: Text(
            'Error executing commands: $e',
            style: TextStyle(color: slapp_color.white),
          ),
          showCloseIcon: true,
          closeIconColor: slapp_color.white,
        ));
      } finally {
        client.close();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          backgroundColor: slapp_color.success,
          content: Text(
            "Install Completed",
            style: TextStyle(color: slapp_color.white),
          ),
          showCloseIcon: true,
          closeIconColor: slapp_color.white,
        ));
        _progressNotifier.value = "Install Completed";
        await Future.delayed(Duration(seconds: 3));
        setState(() {
          is_install = false;
          install_completed = true;
        });
        removeFile(_filePath);
      }
    } catch (e) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        backgroundColor: slapp_color.error,
        content: Text(
          "Cannot Conenct SSH: $e",
          style: TextStyle(color: slapp_color.white),
        ),
        showCloseIcon: true,
        closeIconColor: slapp_color.white,
      ));
    }
  }

  Future<void> removeFileFromServer() async {
    try {
      // Connect to the SSH server
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      // Execute the `rm` command to delete the file
      final rmCommand = "rm -f $_filePath_server";
      final rmSession = await client.execute(rmCommand);

      // Read and print the output (if any) for debugging
      final output = await rmSession.stdout.join();
      await rmSession.done;

      print("File removed successfully. Command output: $output");

      // Close the SSH client
      client.close();
    } catch (e) {
      print("Error while removing file: $e");
    }
  }

  Future<void> unzipFileUsingDartSSH2({
    required String host,
    required int port,
    required String username,
    required String password,
    required String remoteZipFilePath,
    required String destinationPath,
    required Function(String) onProgress,
  }) async {
    try {
      // Connect to the SSH server
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      // Check the size of the zip file for progress calculation
      final statCommand = "stat -c%s $remoteZipFilePath";
      final statSession = await client.execute(statCommand);

      final statResult = await statSession.stdout.join();
      await statSession.done;

      final fileSize =
          int.tryParse(statResult.trim()) ?? 1; // Avoid division by zero

      // Run the unzip command
      final unzipCommand = "unzip -o $remoteZipFilePath -d $destinationPath";
      final unzipSession = await client.execute(unzipCommand);

      int bytesProcessed = 0;

      // Track progress from the unzip output
      unzipSession.stdout.listen((data) {
        final output = String.fromCharCodes(data);
        print(output); // Log the output for debugging

        // Example progress tracking logic
        bytesProcessed += data.length;
        final double progress = (bytesProcessed / fileSize) * 100;
        onProgress("Unzipping progress: ${progress.toStringAsFixed(2)}%");
      });

      // Wait for the unzip command to complete
      await unzipSession.done;
      print("Unzipping complete!");
      _progressNotifier.value = "Installing Update, Please Wait...";
      setState(() {
        is_unzip = false;
      });
      removeFileFromServer();
      runCommands();

      // Close the SSH client
      client.close();
    } catch (e) {
      print("Error while unzipping: $e");
    }
  }

  void startUnzip() async {
    setState(() {
      is_unzip = true;
    });
    await unzipFileUsingDartSSH2(
      host: host,
      port: 22,
      username: username,
      password: password,
      remoteZipFilePath: remoteZipFile,
      destinationPath: destinationzipPath,
      onProgress: (progress) {
        _progressNotifier.value = "Unziping Update File, Please Wait...";
        print(progress);
      },
    );
  }

  Future<void> uploadFileToSSHServer() async {
    setState(() {
      is_transfer = true;
      is_checkwifi = false;
    });
    String localFilePath = _filePath;
    String remoteFilePath = _filePath_server;
    _progressNotifier.value =
        "Starting to Transfer File to SAILOGGER-DEVICE, Please Wait...";
    try {
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      // Start an SFTP session
      print('Starting SFTP session...');
      _progressNotifier.value =
          "Starting SFTP Session to SAILOGGER-DEVICE, Please Wait...";
      final sftp = await client.sftp();

      // Read the local file
      final file = File(localFilePath);
      if (!await file.exists()) {
        print('Local file does not exist at $localFilePath');
        return;
      }

      final fileContents = await file.readAsBytes();

      // Convert file contents to a Stream<Uint8List>
      final fileContentsStream = Stream<Uint8List>.fromIterable([fileContents]);
      _progressNotifier.value =
          "Copying File to SAILOGGER-DEVICE Please Wait...(10-25 minutes)";
      // Upload the file to the server
      print('Uploading file to $remoteFilePath...');
      final remoteFile = await sftp.open(
        remoteFilePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );
      await remoteFile.write(fileContentsStream);
      await remoteFile.close();
      _progressNotifier.value = "File Succsessfully Copied to SAILOGGER-DEVICE";
      print('File uploaded successfully to $remoteFilePath');
      setState(() {
        is_transfer = false;
      });

      startUnzip();
      // Close the SFTP session
      sftp.close();
    } catch (e) {
      setState(() {
        is_install = false;
      });
      print('An error occurred: $e');
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        backgroundColor: slapp_color.error,
        content: Text(
          "$e",
          style: TextStyle(color: slapp_color.white),
        ),
        showCloseIcon: true,
        closeIconColor: slapp_color.white,
      ));
    } finally {
      print('Closing connection...');
    }
  }

  Future<void> compareRemoteFileContent() async {
    try {
      // Establish SSH connection
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      // Open SFTP session
      final sftp = await client.sftp();

      // Read file content
      final file = await sftp.open(_versionPath, mode: SftpFileOpenMode.read);
      final content = await file.readBytes();
      await file.close();

      // Convert content to string
      final fileContent = utf8.decode(content);

      // Compare file content with the given string
      if (fileContent.contains('7.19')) {
        print('File content matches the expected content!');
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          backgroundColor: slapp_color.primary,
          content: Text(
            "SAILOGGER-NEO IS ALREADY ON VERSION 7.19",
            style: TextStyle(color: slapp_color.white),
          ),
          showCloseIcon: true,
          closeIconColor: slapp_color.white,
        ));
        removeFile(_filePath);
        setState(() {
          install_satisfied = true;
        });
      } else {
        print('File content not match expected content!');
        uploadFileToSSHServer();
      }

      // Close the connection
      client.close();
    } catch (e) {
      print('Error File Version: $e');
      uploadFileToSSHServer();
    }
  }

  Future<void> copyFileToPublicDir(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final sourcePath = '${directory.path}/$fileName';
    final targetPath = '/sdcard/Download/$fileName';

    try {
      File(sourcePath).copySync(targetPath);
      setState(() {
        _filePath = targetPath;
      });
      print('File copied to $targetPath');
    } catch (e) {
      print('Error copying file: $e');
    }
  }

  Future<bool> requestStoragePermission() async {
  // Check the current permission status
  final status = await Permission.storage.status;

  if (status.isGranted) {
    // Permission is already granted
    print("Storage permission is already granted.");
    return true;
  } else if (status.isDenied || status.isRestricted) {
    // Request permission
    final result = await Permission.storage.request();

    if (result.isGranted) {
      // Permission granted after request
      print("Storage permission granted.");
      return true;
    } else if (result.isPermanentlyDenied) {
      // If permanently denied, guide the user to settings
      print("Storage permission is permanently denied. Redirecting to settings...");
      openAppSettings();
    } else {
      // Permission denied
      print("Storage permission denied.");
      return false;
    }
  }
  return false;
}

  Future<void> removeFile(filepath) async {
    final file = File(filepath);
    try {
      if (await file.exists()) {
        await file.delete();
        print('File deleted successfully');
      } else {
        print('File does not exist');
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  Future<void> downloadFile(String url, String filename) async {
    setState(() {
      is_download = true;
      error_download = false;
    });
    fetchCommands();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';

      print('Downloading to: $filePath');

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final percentage = (received / total * 100).toStringAsFixed(0);
            setState(() {
              status_download = double.parse(percentage);
            });
            print('Progress: $percentage%');
          }
        },
      );
      copyFileToPublicDir(filename);
      print('Download completed: $filePath');
      fetchCommands();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        backgroundColor: slapp_color.success,
        content: Text(
          "Download completed: $filePath",
          style: TextStyle(color: slapp_color.white),
        ),
        showCloseIcon: true,
        closeIconColor: slapp_color.white,
      ));
      setState(() {
        is_download = false;
      });
    } catch (e) {
      print('Download failed: $e');
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        backgroundColor: slapp_color.error,
        content: Text(
          'Download failed: Check your internet connection',
          style: TextStyle(color: slapp_color.white),
        ),
        showCloseIcon: true,
        closeIconColor: slapp_color.white,
      ));
      setState(() {
        error_download = true;
      });
    }
  }

  Future<void> checkFileExists(String filePath) async {
    File file = File(filePath);

    if (await file.exists()) {
      print("File exists at $filePath");
      setState(() {
        _filePath = filePath;
      });
    } else {
      print("File does not exist at $filePath");
      setState(() {
        _filePath = '';
      });
    }
  }

  Future<void> checkFile() async {
    String filePath =
        '/sdcard/Download/$down_filename'; // Replace with your file path
    await checkFileExists(filePath);
  }

  Future<void> requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      print("Location Permission Granted");
    } else if (status.isDenied) {
      print("Location Permission Denied");
    } else if (status.isPermanentlyDenied) {
      print("Location Permission Permanently Denied");
      openAppSettings();
    }
  }


void requestStorage() async {
  final hasPermission = await requestStoragePermission();

  if (hasPermission) {
    print("You can now access storage!");
  } else {
    print("Storage access is not permitted.");
  }
}
  @override
  void initState() {
    _initPackageInfo();
    checkFile();
    getCurrentWifiSSID();
    requestLocationPermission();
    requestStorage();
    fetchCommands();
    startMonitoringSSID();
    super.initState();
  }

  void startMonitoringSSID() {
    ssidCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      final newSSID = await WiFiForIoTPlugin.getSSID();
      if (newSSID != _ssid) {
        setState(() {
          _ssid = newSSID;
        });
        if (is_install) {
          onSSIDChange(newSSID);
        }
      }
    });
  }

  void onSSIDChange(String? newSSID) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => HomeScreen()));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      backgroundColor: slapp_color.error,
      content: Text(
        "Install Failed, Please Stay Connect to SAILOGGER-HOTSPOT",
        style: TextStyle(color: slapp_color.white),
      ),
      showCloseIcon: true,
      closeIconColor: slapp_color.white,
    ));
  }

  @override
  void dispose() {
    ssidCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: slapp_color.fifthiary.withOpacity(0.2),
        title: Text(
          'Wi-Fi : $_ssid',
          style: TextStyle(color: slapp_color.primary, fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: () {
              getCurrentWifiSSID();
            },
            icon: Icon(
              Icons.refresh,
              color: slapp_color.primary,
            ),
          ),
        ],
      ),
      backgroundColor: slapp_color.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 10,
              ),
              is_download
                  ? CircularPercentIndicator(
                      radius: 100.0,
                      lineWidth: 20.0,
                      animateFromLastPercent: true,
                      animation: true,
                      percent: status_download / 100,
                      center: error_download
                          ? IconButton(
                              onPressed: () {
                                downloadFile(_url + down_link, down_filename);
                              },
                              icon: Icon(
                                Icons.replay_circle_filled,
                                size: 45.0,
                                color: slapp_color.secondary,
                              ))
                          : Image.asset(
                              'assets/images/download.gif',
                              fit: BoxFit.fill,
                              height: 130.0,
                              width: 130.0,
                            ),
                      progressColor: error_download
                          ? slapp_color.error
                          : slapp_color.primary,
                    )
                  : (install_completed && !is_install
                      ? Image.asset(
                          'assets/images/complete.gif',
                          fit: BoxFit.fill,
                          height: 150.0,
                          width: 150.0,
                        )
                      : is_install
                          ? (install_satisfied
                              ? Image.asset(
                                  'assets/images/already.gif',
                                  fit: BoxFit.fill,
                                  height: 150.0,
                                  width: 150.0,
                                )
                              : (is_error_cmd
                                  ? IconButton(
                                      onPressed: runCommands,
                                      icon: Icon(
                                          color: slapp_color.black_text,
                                          Icons.replay_circle_filled_outlined))
                                  : (is_checkwifi
                                      ? Image.asset(
                                          'assets/images/wifi.gif',
                                          fit: BoxFit.fill,
                                          height: 150.0,
                                          width: 150.0,
                                        )
                                      : is_transfer
                                          ? Image.asset(
                                              'assets/images/upload_static.png',
                                              fit: BoxFit.fill,
                                              height: 100.0,
                                              width: 100.0,
                                            )
                                          : is_unzip
                                              ? Image.asset(
                                                  'assets/images/unzip.gif',
                                                  fit: BoxFit.fill,
                                                  height: 150.0,
                                                  width: 150.0,
                                                )
                                              : Image.asset(
                                                  'assets/images/command.gif',
                                                  fit: BoxFit.fill,
                                                  height: 150.0,
                                                  width: 150.0,
                                                ))))
                          : (install_satisfied
                              ? Icon(
                                  Icons.close,
                                  size: 120,
                                  color: slapp_color.error,
                                )
                              : (_filePath.length > 0
                                  ? Image.asset(
                                      'assets/images/ready_install.gif',
                                      fit: BoxFit.fill,
                                      height: 150.0,
                                      width: 150.0,
                                    )
                                  : Image.asset(
                                      'assets/images/updates.gif',
                                      fit: BoxFit.fill,
                                      height: 150.0,
                                      width: 150.0,
                                    )))),
              SizedBox(
                height: 16.9,
              ),
              !install_completed
                  ? (install_satisfied
                      ? Padding(
                          padding: EdgeInsets.all(20.0),
                          child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(color: slapp_color.secondary),
                                children: <TextSpan>[
                                  TextSpan(
                                      text:
                                          'Sailogger is Already on Version 7.19',
                                      style: TextStyle(
                                          color: slapp_color.black_text,
                                          fontSize: 20)),
                                ],
                              )),
                        )
                      : (!is_install && !is_download
                          ? (_filePath.length > 0
                              ? Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: TextStyle(
                                            color: slapp_color.secondary),
                                        children: <TextSpan>[
                                          TextSpan(
                                              text:
                                                  'Update File is Ready to Install, ',
                                              style: TextStyle(
                                                  color: slapp_color.black_text,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold)),
                                          TextSpan(
                                              text:
                                                  'Please Click Install Button ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: slapp_color.primary,
                                                  fontSize: 20)),
                                        ],
                                      )),
                                )
                              : Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: TextStyle(
                                            color: slapp_color.secondary),
                                        children: <TextSpan>[
                                          TextSpan(
                                              text:
                                                  'Please follow 2 steps bellow to update your ',
                                              style: TextStyle(
                                                  color: slapp_color.black_text,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold)),
                                          TextSpan(
                                              text: 'SAILOGGER-SOFTWARE ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: slapp_color.primary,
                                                  fontSize: 15)),
                                        ],
                                      )),
                                ))
                          : Container()))
                  : Padding(
                      padding: EdgeInsets.all(20.0),
                      child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(color: slapp_color.secondary),
                            children: <TextSpan>[
                              TextSpan(
                                  text: 'Sailogger Update is completed ',
                                  style: TextStyle(
                                      color: slapp_color.black_text,
                                      fontSize: 20)),
                            ],
                          )),
                    ),
              (is_install || is_download) && !install_satisfied
                  ? Text('STATUS:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: slapp_color.primary))
                  : Container(),
              is_download
                  ? Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        "Ongoing Download : " +
                            status_download
                                .toStringAsFixed(0)
                                .replaceAll('.0', '') +
                            "%",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            color: slapp_color.black_text,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  : Container(),
              is_install && !install_satisfied
                  ? Padding(
                      padding:
                          EdgeInsets.only(bottom: 20.0, left: 20, right: 20),
                      child: ValueListenableBuilder<String>(
                        valueListenable: _progressNotifier,
                        builder: (context, value, child) {
                          return Center(
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 20,
                                  color: slapp_color.black_text,
                                  fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    )
                  : Container(),
              is_install
                  ? Padding(
                      padding:
                          EdgeInsets.only(bottom: 60.0, left: 20, right: 20),
                      child: Text(
                        textAlign: TextAlign.center,
                        "DO NOT CLOSE THE APPLICATION, OR INSTALL WILL BE FAILED!",
                        style: TextStyle(
                          color: slapp_color.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Container(),
              Padding(
                padding: EdgeInsets.only(bottom: 20.0),
                child: Divider(
                  color: slapp_color.fifthiary,
                ),
              ),
              !install_completed
                  ? (!install_satisfied
                      ? Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 20),
                          child: RichText(
                              textAlign: TextAlign.start,
                              text: TextSpan(
                                style: TextStyle(color: slapp_color.secondary),
                                children: const <TextSpan>[
                                  TextSpan(
                                      text: '1. Connect your phone to ',
                                      style: TextStyle(
                                          color: slapp_color.black_text)),
                                  TextSpan(
                                      text: 'STABLE INTERNET CONNECTION ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: slapp_color.primary)),
                                  TextSpan(
                                      text: 'and click download bellow: ',
                                      style: TextStyle(
                                          color: slapp_color.black_text)),
                                ],
                              )),
                        )
                      : Container())
                  : Container(),
              !install_completed
                  ? (!install_satisfied
                      ? Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 20),
                          child: ElevatedButton(
                              style: ButtonStyle(
                                shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                    const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                )),
                                backgroundColor:
                                    MaterialStateProperty.resolveWith<Color>(
                                  (Set<MaterialState> states) {
                                    return _filePath.length > 0
                                        ? slapp_color.sixtiary
                                        : (is_download
                                            ? slapp_color.sixtiary
                                            : slapp_color
                                                .primary); // Defer to the widget's default.
                                  },
                                ),
                                elevation:
                                    MaterialStateProperty.resolveWith<double>(
                                  // As you said you dont need elevation. I'm returning 0 in both case
                                  (Set<MaterialState> states) {
                                    if (states
                                        .contains(MaterialState.disabled)) {
                                      return 0;
                                    }
                                    return 0; // Defer to the widget's default.
                                  },
                                ),
                              ),
                              onPressed: () async {
                                if (_filePath.length > 0) {
                                  ScaffoldMessenger.maybeOf(context)
                                      ?.showSnackBar(SnackBar(
                                    backgroundColor: slapp_color.primary,
                                    content: Text(
                                      "Download Has Been Completed, Please Connect to SAILOGGER-HOTSPOT and Install",
                                      style:
                                          TextStyle(color: slapp_color.white),
                                    ),
                                    showCloseIcon: true,
                                    closeIconColor: slapp_color.white,
                                  ));
                                } else {
                                  if (is_download) {
                                    ScaffoldMessenger.maybeOf(context)
                                        ?.showSnackBar(SnackBar(
                                      backgroundColor: slapp_color.error,
                                      content: Text(
                                        "Download is ON-PROGGRESS",
                                        style:
                                            TextStyle(color: slapp_color.white),
                                      ),
                                      showCloseIcon: true,
                                      closeIconColor: slapp_color.white,
                                    ));
                                  } else {
                                    downloadFile(
                                        _url + down_link, down_filename);
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    is_download
                                        ? SizedBox(
                                            child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                              color: slapp_color.white,
                                            )),
                                            height: 20.0,
                                            width: 20.0,
                                          )
                                        : Icon(
                                            Icons.download,
                                            color: slapp_color.white,
                                          ),
                                    const SizedBox(
                                      width: 10.0,
                                    ),
                                    Text(
                                      "Download Update".toUpperCase(),
                                      style: const TextStyle(
                                          color: slapp_color.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )),
                        )
                      : Container())
                  : Container(),
              !install_completed
                  ? (!install_satisfied
                      ? Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 20),
                          child: RichText(
                              textAlign: TextAlign.start,
                              text: TextSpan(
                                style: TextStyle(color: slapp_color.secondary),
                                children: const <TextSpan>[
                                  TextSpan(
                                      text: '2. Connect your phone to ',
                                      style: TextStyle(
                                          color: slapp_color.black_text)),
                                  TextSpan(
                                      text: 'SAILOGGER-HOTSPOT ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: slapp_color.primary)),
                                  TextSpan(
                                      text: 'and click install bellow: ',
                                      style: TextStyle(
                                          color: slapp_color.black_text)),
                                ],
                              )),
                        )
                      : Container())
                  : Container(),
              !install_completed
                  ? (!install_satisfied
                      ? Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 20),
                          child: ElevatedButton(
                              style: ButtonStyle(
                                shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                    const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                )),
                                backgroundColor:
                                    MaterialStateProperty.resolveWith<Color>(
                                  (Set<MaterialState> states) {
                                    return (_filePath.length > 0) &&
                                            (_commands.length > 0)
                                        ? (is_install || install_completed
                                            ? slapp_color.sixtiary
                                            : slapp_color.primary)
                                        : slapp_color
                                            .sixtiary; // Defer to the widget's default.
                                  },
                                ),
                                elevation:
                                    MaterialStateProperty.resolveWith<double>(
                                  // As you said you dont need elevation. I'm returning 0 in both case
                                  (Set<MaterialState> states) {
                                    if (states
                                        .contains(MaterialState.disabled)) {
                                      return 0;
                                    }
                                    return 0; // Defer to the widget's default.
                                  },
                                ),
                              ),
                              onPressed: () async {
                                if ((_filePath.length > 0) &&
                                    (_commands.length > 0)) {
                                  // Compare the current SSID with the desired one
                                  if (is_install) {
                                    ScaffoldMessenger.maybeOf(context)
                                        ?.showSnackBar(SnackBar(
                                      backgroundColor: slapp_color.error,
                                      content: Text(
                                        "Update is ON-PROGGRESS, Please Wait.",
                                        style:
                                            TextStyle(color: slapp_color.white),
                                      ),
                                      showCloseIcon: true,
                                      closeIconColor: slapp_color.white,
                                    ));
                                  } else if (install_completed) {
                                    ScaffoldMessenger.maybeOf(context)
                                        ?.showSnackBar(SnackBar(
                                      backgroundColor: slapp_color.primary,
                                      content: Text(
                                        "Sailogger already update to SAILOGGER-7.19",
                                        style:
                                            TextStyle(color: slapp_color.white),
                                      ),
                                      showCloseIcon: true,
                                      closeIconColor: slapp_color.white,
                                    ));
                                  } else {
                                    _progressNotifier.value =
                                        "Checking Device Connection...";
                                    setState(() {
                                      is_install = true;
                                      is_checkwifi = true;
                                    });
                                    getCurrentWifiSSID();
                                    await Future.delayed(Duration(seconds: 10));
                                    if (_ssid
                                            .toString()
                                            .toUpperCase()
                                            .contains('SAILOGGER') ||
                                        _ssid
                                            .toString()
                                            .toUpperCase()
                                            .contains('SAILINK')) {
                                      setState(() {});
                                      await Future.delayed(
                                          Duration(seconds: 3));
                                      checkAndDeleteFile();
                                    } else {
                                      ScaffoldMessenger.maybeOf(context)
                                          ?.showSnackBar(SnackBar(
                                        backgroundColor: slapp_color.error,
                                        content: Text(
                                          "Please Connect to SAILOGGER-HOTSPOT",
                                          style: TextStyle(
                                              color: slapp_color.white),
                                        ),
                                        showCloseIcon: true,
                                        closeIconColor: slapp_color.white,
                                      ));
                                      setState(() {
                                        is_install = false;
                                        is_transfer = false;
                                      });
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.maybeOf(context)
                                      ?.showSnackBar(SnackBar(
                                    backgroundColor: slapp_color.error,
                                    content: Text(
                                      "Please Download Update First",
                                      style:
                                          TextStyle(color: slapp_color.white),
                                    ),
                                    showCloseIcon: true,
                                    closeIconColor: slapp_color.white,
                                  ));
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    is_install
                                        ? Icon(
                                            Icons.arrow_circle_up_rounded,
                                            color: slapp_color.white,
                                          )
                                        : Icon(
                                            Icons.install_desktop,
                                            color: slapp_color.white,
                                          ),
                                    const SizedBox(
                                      width: 10.0,
                                    ),
                                    Text(
                                      "Install Update".toUpperCase(),
                                      style: const TextStyle(
                                          color: slapp_color.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )),
                        )
                      : Container())
                  : Container(),
              install_completed || install_satisfied
                  ? Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                      child: ElevatedButton(
                          style: ButtonStyle(
                            shape: MaterialStateProperty.all<
                                    RoundedRectangleBorder>(
                                const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            )),
                            backgroundColor:
                                MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                return slapp_color
                                    .primary; // Defer to the widget's default.
                              },
                            ),
                            elevation:
                                MaterialStateProperty.resolveWith<double>(
                              // As you said you dont need elevation. I'm returning 0 in both case
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return 0;
                                }
                                return 0; // Defer to the widget's default.
                              },
                            ),
                          ),
                          onPressed: () async {
                            exit(0);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.close,
                                  color: slapp_color.white,
                                ),
                                const SizedBox(
                                  width: 10.0,
                                ),
                                Text(
                                  "Close Sailogger-7.19 Updater".toUpperCase(),
                                  style: const TextStyle(
                                      color: slapp_color.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                    )
                  : Container(),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: Container(
      //     color: slapp_color.tertiary,
      //     child: Padding(
      //       padding: MediaQuery.of(context).viewInsets,
      //       child:  Container(
      //               margin: const EdgeInsets.symmetric(
      //                   vertical: 10, horizontal: 20),
      //               child: ElevatedButton(
      //                   style: ButtonStyle(
      //                     shape:
      //                         MaterialStateProperty.all<RoundedRectangleBorder>(
      //                             const RoundedRectangleBorder(
      //                       borderRadius: BorderRadius.zero,
      //                     )),
      //                     backgroundColor:
      //                         MaterialStateProperty.resolveWith<Color>(
      //                       (Set<MaterialState> states) {
      //                         return slapp_color.primary;
      //                       },
      //                     ),
      //                     elevation: MaterialStateProperty.resolveWith<double>(
      //                       // As you said you dont need elevation. I'm returning 0 in both case
      //                       (Set<MaterialState> states) {
      //                         if (states.contains(MaterialState.disabled)) {
      //                           return 0;
      //                         }
      //                         return 0; // Defer to the widget's default.
      //                       },
      //                     ),
      //                   ),
      //                   onPressed: () {
      //                   },
      //                   child: Padding(
      //                     padding: const EdgeInsets.all(10),
      //                     child: Row(
      //                       mainAxisAlignment: MainAxisAlignment.center,
      //                       children: [
      //                         Text(
      //                            "Start Action".toUpperCase(),
      //                           style: const TextStyle(
      //                               color: slapp_color.white,
      //                               fontSize: 16,
      //                               fontWeight: FontWeight.bold),
      //                         ),
      //                       ],
      //                     ),
      //                   )),
      //             )
      //           ,
      //     ),),
    );
  }
}
