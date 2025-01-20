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
import 'package:sailogger719/screens/ssh_check_.dart';
import 'package:sailogger719/screens/ssh_update.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String host = '172.24.1.1';
  final int port = 22;
  final String username = 'skyflix';
  final String password = 'byskyreach';
  final Dio _dio = Dio();
  bool is_download = false;
  bool is_install = false;
  bool is_verify = false;
  bool error_download = false;
  double status_download = 0.0;
  String _filePath = '';
  String? ssid = "Unknown";
  String down_link =
      'https://navigatorplus.sailink.id/sources/SL-Engine-3.17.3A.zip';
  String down_filename = 'SL-Engine-3.17.3A.zip';
  String _filePath_server = '/PyServer/SL-Engine-3.17.3A.zip';
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> uploadFileToSSHServer() async {
    String localFilePath = _filePath;
    String remoteFilePath = _filePath_server;

    setState(() {
      is_install = true;
    });

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
        is_install = false;
      });

      runCommands();
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

  Future<void> runCommands() async {
    List<String> commands = [
      'echo "Command 1: Listing files"',
      'ls -l',
      'echo "Command 2: Checking disk space"',
      'df -h',
      'echo "Command 3: Displaying system uptime"',
      'uptime'
    ];
    try {
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      try {
        for (var command in commands) {
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
        setState(() {
          is_install = false;
        });
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

  Future<void> sendCommandToServer() async {
    try {
      // Create an SSH client
      final client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      // Execute a command
      final session = await client.execute('sudo reboot');

      // Collect the output
      final stdout = await session.stdout
          .map((event) => event as List<int>)
          .transform(utf8.decoder)
          .join();

      final stderr = await session.stderr
          .map((event) => event as List<int>)
          .transform(utf8.decoder)
          .join();

      print('Output:');
      print(stdout);

      if (stderr.isNotEmpty) {
        print('Error:');
        print(stderr);
      }

      // Close the session and client
      session.close();
      client.close();
    } catch (e) {
      print('An error occurred: $e');
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

  Future<void> downloadFile(String url, String filename) async {
    setState(() {
      is_download = true;
      error_download = false;
    });
    try {
      // Get the directory to save the file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';

      print('Downloading to: $filePath');

      // Start the download with progress tracking
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
        backgroundColor: slapp_color.success,
        content: Text(
          'Download failed: $e',
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
    // Request permission to access location
    if (await Permission.location.request().isGranted) {
      try {
        final info = NetworkInfo();
        final currentSSID = await info.getWifiName(); // Get current SSID

        setState(() {
          ssid = currentSSID ?? "No Wi-Fi connected";
        });
      } catch (e) {
        setState(() {
          ssid = "Failed to get SSID: $e";
        });
      }
    } else {
      setState(() {
        ssid = "Location permission denied";
      });
    }
  }

  @override
  void initState() {
    _initPackageInfo();
    checkFile();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slapp_color.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icon_sl.png',
                fit: BoxFit.fill,
                height: 100.0,
                width: 100.0,
              ),
              Padding(
                padding: EdgeInsets.all(20.0),
                child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(color: slapp_color.secondary),
                      children: const <TextSpan>[
                        TextSpan(
                            text: 'Welcome to ',
                            style: TextStyle(color: slapp_color.black_text)),
                        TextSpan(
                            text: 'SAILOGGER 7.19 - UPDATER, ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: slapp_color.primary)),
                        TextSpan(
                            text: 'Please click button bellow to ',
                            style: TextStyle(color: slapp_color.black_text)),
                        TextSpan(
                            text: 'START UPDATE ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: slapp_color.primary)),
                      ],
                    )),
              ),
              Divider(
                color: slapp_color.fifthiary,
              ),
              Container(
                margin:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: ElevatedButton(
                    style: ButtonStyle(
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      )),
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          return is_verify
                              ? slapp_color.sixtiary
                              : slapp_color
                                  .primary; // Defer to the widget's default.
                        },
                      ),
                      elevation: MaterialStateProperty.resolveWith<double>(
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
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SSHCheckerScreen()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          is_download
                              ? SizedBox(
                                  child: Center(
                                      child: CircularProgressIndicator(
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
                            "Start Update".toUpperCase(),
                            style: const TextStyle(
                                color: slapp_color.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
              ),
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
