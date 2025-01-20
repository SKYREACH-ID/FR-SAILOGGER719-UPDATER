import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter/material.dart';
import 'package:sailogger719/constant/colors.dart';
import 'package:dartssh2/dartssh2.dart';

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
      // Open the SFTP subsystem
      final channel = await client.execute('sftp');

      // Create an SFTP client using the channel
      final sftpClient = SftpClient(channel as SSHChannel);

      // Open and read the file
      final file = await sftpClient.open(filePath, mode: SftpFileOpenMode.read);
      final fileContent = await file.readBytes();

      // Print the file content
      print(String.fromCharCodes(fileContent));
      setState(() {
        iot_id = String.fromCharCodes(fileContent);
      });

      // Clean up resources
      await file.close();

      sftpClient.close();
      sshClient.close();
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    readFileViaSSH();
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
                          text: ' SAILOGGER-IOT-ID: '+ iot_id,
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
