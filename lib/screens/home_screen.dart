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
import 'package:wifi_iot/wifi_iot.dart';
// import 'package:percent_indicator/circular_percent_indicator.dart';
// import 'package:sailogger719/screens/ssh_check_.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String host = '172.24.1.1';
  final int port = 22;
  final String username = 'skyflix';
  final String password = 'byskyreach';
  bool _isCheckingVersion = false;
  String? _ssid = "";
  bool _isDeviceConnected = false;

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

  Future<String> _runSshCommand(SSHClient client, String command) async {
    final result = await client.run(command);
    try {
      return utf8.decode(result, allowMalformed: true).trim();
    } catch (_) {
      return latin1.decode(result, allowInvalid: true).trim();
    }
  }

  String _extractVersion(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return "-";
    final regex = RegExp(r'(\d+\.\d+(?:\.\d+)?)');
    final match = regex.firstMatch(clean);
    return match?.group(1) ?? clean;
  }

  bool _isDeviceWifiSsid(String ssid) {
    final normalized = ssid.replaceAll('"', '').trim().toUpperCase();
    return normalized.contains('SAILOGGER') || normalized.contains('SAILINK');
  }

  bool _isUnknownSsid(String ssid) {
    final normalized = ssid.replaceAll('"', '').trim().toUpperCase();
    return normalized.isEmpty ||
        normalized == '<UNKNOWN SSID>' ||
        normalized == 'UNKNOWN SSID' ||
        normalized == 'NO WI-FI CONNECTED';
  }

  bool _isDeviceSubnetIp(String ip) {
    final normalized = ip.trim();
    return normalized.startsWith('172.24.1.');
  }

  Future<bool> _isDeviceReachable() async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> getCurrentWifiSSID() async {
    setState(() {
      _ssid = 'Loading...';
    });

    try {
      final status = await Permission.location.status;
      if (!status.isGranted) {
        await Permission.location.request();
      }
      final ssid = await WiFiForIoTPlugin.getSSID();
      final wifiIp = await NetworkInfo().getWifiIP();
      final normalized = (ssid ?? '').replaceAll('"', '').trim();
      final bySsid = _isDeviceWifiSsid(normalized);
      final bySubnet = _isDeviceSubnetIp(wifiIp ?? '');
      final byIp = await _isDeviceReachable();
      setState(() {
        _ssid = _isUnknownSsid(normalized) && (wifiIp?.isNotEmpty ?? false)
            ? 'UNKNOWN SSID (${wifiIp!})'
            : normalized;
        _isDeviceConnected = bySsid || bySubnet || byIp;
      });
    } catch (_) {
      final byIp = await _isDeviceReachable();
      setState(() {
        _ssid = "";
        _isDeviceConnected = byIp;
      });
    }
  }


  Future<bool> _ensureConnectedToDeviceWifi() async {
    String lastSsid = '';
    for (var i = 0; i < 3; i++) {
      final wifiName = await WiFiForIoTPlugin.getSSID();
      lastSsid = (wifiName ?? '').replaceAll('"', '').trim().toUpperCase();
      final isDeviceWifi = _isDeviceWifiSsid(lastSsid);
      if (isDeviceWifi) {
        if (mounted) {
          setState(() {
            _ssid = wifiName ?? "";
            _isDeviceConnected = true;
          });
        }
        return true;
      }
      await Future.delayed(Duration(milliseconds: 700));
    }

    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      if (mounted) {
        setState(() {
          _ssid = lastSsid;
          _isDeviceConnected = true;
        });
      }
      return true;
    } catch (_) {}

    if (!mounted) return false;
    final currentSsidText = lastSsid.isEmpty ? '-' : lastSsid;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: slapp_color.error,
        content: Text(
          "Please Connect to SAILOGGER-HOTSPOT (SSID: $currentSsidText)",
          style: TextStyle(color: slapp_color.white),
        ),
        showCloseIcon: true,
        closeIconColor: slapp_color.white,
      ),
    );
    return false;
  }

  Future<void> checkSpecialVersionCondition() async {
    if (_isCheckingVersion) return;
    setState(() {
      _isCheckingVersion = true;
    });
    final isConnected = await _ensureConnectedToDeviceWifi();
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _isCheckingVersion = false;
        });
      }
      return;
    }

    SSHClient? client;
    try {
      client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        onPasswordRequest: () => password,
      );

      final runlevelRaw = await _runSshCommand(client, 'runlevel');
      final normalizedRunlevel =
          runlevelRaw.replaceAll(RegExp(r'\s+'), ' ').trim();
      final hasDisplay = normalizedRunlevel == 'N 5';
      final noDisplay = normalizedRunlevel == 'N 3';

      final engineRaw =
          await _runSshCommand(client, "curl -s localhost/api/skychat/version");
      final systemRaw = await _runSshCommand(client, 'cat /System/Version');
      final readerRaw = await _runSshCommand(client, 'cat /var/Python/Version');
      final displayRaw = hasDisplay
          ? await _runSshCommand(
              client, 'cat /PyDashboard/data/view_version.json')
          : "-";

      final iotRunRaw =
          await _runSshCommand(client, '/var/Python/SKYREACH-IoT.RUN');
      final hasIotRunVersion = iotRunRaw.contains('VERSI : 1.0.1');
      final isReader825 = readerRaw.trim() == '8.2.5';
      final logsRaw = await _runSshCommand(client, 'ls -ahl /var/Python/log/ || true');
      final hasARStatusReport = logsRaw.contains('ARStatusReport.json');
      final hasMessageReports = logsRaw.contains('MessageReports.log');
      final isSpecial825A = hasIotRunVersion &&
          isReader825 &&
          hasARStatusReport &&
          hasMessageReports;
      final readerVersionDisplay =
          isSpecial825A ? '8.2.5-A' : _extractVersion(readerRaw);
      final versionMarker =
          isSpecial825A ? '8.2.5-A' : _extractVersion(readerRaw);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Device Check'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Status Layar: ${hasDisplay ? "Ada Layar" : (noDisplay ? "Tanpa Layar" : "Tidak Diketahui ($normalizedRunlevel)")}'),
                SizedBox(height: 10),
                // Text('Engine Version: '),
                Text('System Version: v${_extractVersion(systemRaw)} (${_extractVersion(engineRaw)})'),
                Text('Reader Version: v$readerVersionDisplay', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSpecial825A
                        ? slapp_color.success
                        : slapp_color.primary,
                  ),
                ),
                if (hasDisplay)
                  Text('Display Version: v${_extractVersion(displayRaw)}'),
                SizedBox(height: 14),
                // Text(
                //   'Version Marker: $versionMarker',
                //   style: TextStyle(
                //     fontWeight: FontWeight.bold,
                //     color: isSpecial825A
                //         ? slapp_color.success
                //         : slapp_color.primary,
                //   ),
                // ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          backgroundColor: slapp_color.error,
          content: Text(
            "Gagal check version: $e",
            style: TextStyle(color: slapp_color.white),
          ),
          showCloseIcon: true,
          closeIconColor: slapp_color.white,
        ),
      );
    } finally {
      client?.close();
      if (mounted) {
        setState(() {
          _isCheckingVersion = false;
        });
      }
    }
  }

  @override
  void initState() {
    _initPackageInfo();
    Permission.location.request();
    getCurrentWifiSSID();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: slapp_color.fifthiary.withOpacity(0.2),
        title: Text(
          'Wi-Fi : ${(_ssid == null || _ssid!.isEmpty) ? "-" : _ssid}',
          style: TextStyle(color: slapp_color.primary, fontSize: 13),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _isDeviceConnected ? 'CONNECTED' : 'NOT CONNECTED',
                style: TextStyle(
                  color:
                      _isDeviceConnected ? slapp_color.success : slapp_color.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ),
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
                              builder: (context) =>
                                  SSHFileTransferScreen(initialSsid: _ssid)));
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
                          if (_isCheckingVersion ||
                              states.contains(MaterialState.disabled)) {
                            return slapp_color.sixtiary;
                          }
                          return slapp_color.primary;
                        },
                      ),
                      elevation: MaterialStateProperty.resolveWith<double>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.disabled)) {
                            return 0;
                          }
                          return 0;
                        },
                      ),
                    ),
                    onPressed: _isCheckingVersion
                        ? null
                        : () async {
                            await checkSpecialVersionCondition();
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isCheckingVersion
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: slapp_color.white,
                                  ),
                                )
                              : Icon(
                                  Icons.rule_folder_outlined,
                                  color: slapp_color.white,
                                ),
                          const SizedBox(
                            width: 10.0,
                          ),
                          Text(
                            "Device Check".toUpperCase(),
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
