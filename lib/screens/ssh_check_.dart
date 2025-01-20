import 'package:flutter/material.dart';
import 'package:sailogger719/constant/colors.dart';

class SSHCheckerScreen extends StatefulWidget {
  const SSHCheckerScreen({super.key});

  @override
  State<SSHCheckerScreen> createState() => _SSHCheckerScreenState();
}

class _SSHCheckerScreenState extends State<SSHCheckerScreen> {
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
                    children: const <TextSpan>[
                      TextSpan(
                          text: 'Checking',
                          style: TextStyle(color: slapp_color.black_text)),
                      TextSpan(
                          text: ' SAILOGGER-IOT-ID ',
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
