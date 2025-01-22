import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:sailogger719/constant/colors.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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

  Future<void> runCommandsWithProgress(
      {required List<String> commands,
      required ValueNotifier<String> progressNotifier,
      required Function() onCommandCompletion,
      required VoidCallback onCommandError}) async {
    try {
      // Connect to the remote server
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      final totalCommands = commands.length;
      int completedCommands = 0;

      for (final command in commands) {
        // Update progress before running the command
        progressNotifier.value =
            "Running: $command (${(completedCommands / totalCommands * 100).toStringAsFixed(1)}%)";

        // Execute the command
        final result = await client.execute(command);

        // Update progress after completion
        completedCommands++;
        progressNotifier.value =
            "Completed: $command\nOutput: ${result.stdout}\nProgress: ${(completedCommands / totalCommands * 100).toStringAsFixed(1)}%";
      }

      // Final update
      progressNotifier.value = "All commands executed successfully (100%).";

      onCommandCompletion();
      // Close the SSH connection
      client.close();
    } catch (e) {
      progressNotifier.value = "Error: $e";
      onCommandError();
    }
  }
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
  bool error_download = false;
  bool install_completed = false;
  bool is_error_cmd = false;
  double status_download = 0.0;
  bool install_satisfied = false;
  List<String> _commands = [];
  String _filePath = '';
  String? ssid = "Unknown";
  String _url = "https://navigatorplus.sailink.id/";
  String down_link = 'sources/SAILOGGER-NEO-7.19.zip';
  String down_filename = 'SAILOGGER-NEO-7.19.zip';
  String _filePath_server = '/home/skyflix/SAILOGGER-NEO-7.19.zip';
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

  void _runCommands() async {
    final executor = SSHCommandExecutor(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    await executor.runCommandsWithProgress(
        commands: _commands,
        progressNotifier: _progressNotifier,
        onCommandCompletion: onCommandCompletion,
        onCommandError: onCommandError);
  }

  void onCommandCompletion() async {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      backgroundColor: slapp_color.success,
      content: Text(
        "Install Completed",
        style: TextStyle(color: slapp_color.white),
      ),
      showCloseIcon: true,
      closeIconColor: slapp_color.white,
    ));
    await Future.delayed(Duration(seconds: 3));
    setState(() {
      is_install = false;
      install_completed = true;
    });
    removeFile(_filePath);
  }

  void onUploadCompletion() async {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      backgroundColor: slapp_color.success,
      content: Text(
        "Upload Successfully",
        style: TextStyle(color: slapp_color.white),
      ),
      showCloseIcon: true,
      closeIconColor: slapp_color.white,
    ));
    await Future.delayed(Duration(seconds: 3));
    _runCommands();
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

  // Future<void> runCommands() async {
  //   try {
  //     final client = SSHClient(
  //       await SSHSocket.connect(host, port),
  //       username: username,
  //       onPasswordRequest: () => password,
  //     );

  //     try {
  //       for (var command in _commands) {
  //         print('Running command: $command');
  //         var result = await client.run(command);
  //         print('Result: $result');
  //       }
  //     } catch (e) {
  //       ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
  //         backgroundColor: slapp_color.error,
  //         content: Text(
  //           'Error executing commands: $e',
  //           style: TextStyle(color: slapp_color.white),
  //         ),
  //         showCloseIcon: true,
  //         closeIconColor: slapp_color.white,
  //       ));
  //     } finally {
  //       client.close();
  //       ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
  //         backgroundColor: slapp_color.success,
  //         content: Text(
  //           "Install Completed",
  //           style: TextStyle(color: slapp_color.white),
  //         ),
  //         showCloseIcon: true,
  //         closeIconColor: slapp_color.white,
  //       ));
  //       await Future.delayed(Duration(seconds: 3));
  //       setState(() {
  //         is_install = false;
  //         install_completed = true;
  //       });
  //       removeFile(_filePath);
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
  //       backgroundColor: slapp_color.error,
  //       content: Text(
  //         "Cannot Conenct SSH: $e",
  //         style: TextStyle(color: slapp_color.white),
  //       ),
  //       showCloseIcon: true,
  //       closeIconColor: slapp_color.white,
  //     ));
  //   }
  // }

  Future<void> uploadFileToSSHServer() async {
    String localFilePath = _filePath;
    String remoteFilePath = _filePath_server;
    _progressNotifier.value =
        "Copying File to SAILOGGER-DEVICE Please Wait...(10-25 minutes)";
    try {
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
        keepAliveInterval: Duration(seconds: 30),
        printDebug: (p0) {
          print(p0);
        },
      );

      // Start an SFTP session
      print('Starting SFTP session...');
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

      // Upload the file to the server
      print('Uploading file to $remoteFilePath...');
      final remoteFile = await sftp.open(
        remoteFilePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );
      await remoteFile.write(fileContentsStream);
      await remoteFile.close();

      print('File uploaded successfully to $remoteFilePath');
      setState(() {
        is_transfer = false;
      });

      _runCommands();
      // Close the SFTP session
      sftp.close();
    } catch (e) {
      setState(() {
        is_install = false;
      });
      print('An error occurred: $e');
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
      print('Error: $e');
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
      checkWifi();
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

  Future<void> checkWifi() async {
    if (await Permission.location.request().isGranted) {
      try {
        final info = NetworkInfo();
        final currentSSID = await info.getWifiName(); // Get current SSID

        setState(() {
          ssid = currentSSID ?? "No Wi-Fi connected";
        });
      } catch (e) {
        setState(() {
          ssid = "Failed to get SSID";
        });
      }
    } else {
      setState(() {
        ssid = "Permission Denied";
      });
    }
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

  @override
  void initState() {
    _initPackageInfo();
    checkFile();
    checkWifi();
    requestLocationPermission();
    fetchCommands();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('SSID: $ssid',style: TextStyle(color: slapp_color.primary),),
      //   backgroundColor: slapp_color.tex,
      // ),
      appBar: AppBar(
        centerTitle: true,
         title: Image.asset(
                'assets/images/sailogger_logo_white.png',
                fit: BoxFit.fill,
                height: 23.0,
                width: 210.0,
              ),
        bottom: PreferredSize(
            preferredSize: Size(MediaQuery.of(context).size.width, 60),
            child: Container(
                width: MediaQuery.of(context).size.width,
                height: 50,
                color: slapp_color.black_text,
                child: Padding(
                  padding: EdgeInsets.all(15.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "CONNECTED-WIFI :".toUpperCase(),
                        style: TextStyle(color: slapp_color.white_text),
                      ),
                      Text(
                        ssid.toString().toUpperCase(),
                        style: TextStyle(color: slapp_color.primary),
                      ),
                    ],
                  ),
        )))),
      backgroundColor: slapp_color.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                      ? Icon(
                          Icons.check_circle_outlined,
                          size: 120,
                          color: slapp_color.success,
                        )
                      : is_install
                          ? (install_satisfied
                              ? Icon(
                                  Icons.close,
                                  size: 120,
                                  color: slapp_color.error,
                                )
                              : (is_error_cmd
                                  ? IconButton(
                                      onPressed: _runCommands,
                                      icon: Icon(
                                          color: slapp_color.black_text,
                                          Icons.replay_circle_filled_outlined))
                                  : (is_transfer
                                      ? Image.asset(
                                          'assets/images/upload.gif',
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
                              : Icon(
                                  Icons.update,
                                  size: 120,
                                  color: slapp_color.primary,
                                ))),
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
                                          fontSize: 18)),
                                ],
                              )),
                        )
                      : (!is_install && !is_download
                          ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style:
                                        TextStyle(color: slapp_color.secondary),
                                    children: <TextSpan>[
                                      TextSpan(
                                          text:
                                              'Please follow 2 steps bellow to update your ',
                                          style: TextStyle(
                                              color: slapp_color.black_text)),
                                      TextSpan(
                                          text: 'SAILOGGER-SOFTWARE ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: slapp_color.primary)),
                                    ],
                                  )),
                            )
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
                                      fontSize: 18)),
                            ],
                          )),
                    ),
              is_install || is_download
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
              is_install
                  ? Padding(
                      padding:
                          EdgeInsets.only(bottom: 60.0, left: 20, right: 20),
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
                                    //fetchCommands();
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

                                      is_transfer = true;
                                    });
                                    checkWifi();
                                    await Future.delayed(Duration(seconds: 5));
                                    if (ssid.toString().toUpperCase().contains('SAILOGGER') ||
                                        ssid.toString().toUpperCase().contains('SAILINK')) {
                                      setState(() {});
                                      await Future.delayed(
                                          Duration(seconds: 3));
                                      compareRemoteFileContent();
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
      bottomNavigationBar: Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: SizedBox(
            height: 90,
            child: Container(
              child: Center(
                child: Text(
                    _packageInfo.appName +
                        ' by skyreach v' +
                        _packageInfo.version,
                    style: TextStyle(
                        color: slapp_color.secondary.withOpacity(0.5))),
              ),
            ),
          )),
    );
  }
}
