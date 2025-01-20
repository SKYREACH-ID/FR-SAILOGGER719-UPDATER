import 'dart:io';

import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter/material.dart';
import 'package:sailogger719/constant/colors.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:sailogger719/screens/ssh_update.dart';

class SSHCheckerScreen extends StatefulWidget {
  const SSHCheckerScreen({super.key});

  @override
  State<SSHCheckerScreen> createState() => _SSHCheckerScreenState();
}

class _SSHCheckerScreenState extends State<SSHCheckerScreen> {
  final String host = '172.24.1.1';
  final int port = 22;
  final String username = 'skyflix';
  final String password = 'byskyreach';

  String filePath = '/var/Python/ID-IoT.SKY';
  String iot_id = '';

Future<void> readFileViaSSH() async {
  const host = '172.24.1.1';  // Replace with your SSH server address
  const port = 22;  // Default SSH port
  final String username = 'skyflix';
  final String password = 'byskyreach';// Replace with your password
  String filePath = '/var/Python/Configs/ID-IoT.SKY';  // Replace with the remote file path

  try {
    // Establish SSH connection
    final sshClient = SSHClient(
      await SSHSocket.connect(host, port),
      username: username,
      onPasswordRequest: () => password,  // Provide password for authentication
    );

    print('Connected to SSH server.');

    // Open SFTP session
    final sftp = await sshClient.sftp();

    // Open the file for reading using SftpFileOpenMode.read
    final file = await sftp.open(filePath, mode: SftpFileOpenMode.read);

    // Read the entire file content as bytes
    final fileContent = await file.readBytes();

    print('File Content:');
    print(String.fromCharCodes(fileContent));

    // Close the file and SFTP session
    await file.close();
     sftp.close();

    // Close the SSH connection
    sshClient.close();

    print('File read successfully.');

     Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SSHFileTransferScreen()));
  } catch (e) {
    print('Error: $e');
  }
}
  readSSH(){
      Future.delayed(Duration(seconds: 3), () {
     readFileViaSSH();
  });
    
  }

  @override
  void initState() {
    // TODO: implement initState
    readSSH();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slapp_color.background,
      body: Center(
          child: SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
            SizedBox(
              height: 60.0,
              width: 60.0,
              child: CircularProgressIndicator(
                color: slapp_color.primary,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.0),
              child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(color: slapp_color.secondary),
                    children:  <TextSpan>[
                      TextSpan(
                          text: 'Checking',
                          style: TextStyle(color: slapp_color.black_text)),
                      TextSpan(
                          text: ' SAILOGGER-IOT-ID'+ iot_id,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: slapp_color.primary)),
                      TextSpan(
                          text: 'Availability...',
                          style: TextStyle(color: slapp_color.black_text)),
                    ],
                  )),
            ),
          ]))),
    );
  }
}
