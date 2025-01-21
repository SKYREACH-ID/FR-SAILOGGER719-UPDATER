import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sailogger719/constant/colors.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sailogger719/screens/ssh_update.dart';
// import 'package:percent_indicator/circular_percent_indicator.dart';
// import 'package:sailogger719/screens/ssh_check_.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  void initState() {
    _initPackageInfo();
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
                          return slapp_color
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
                              builder: (context) => SSHFileTransferScreen()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
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
