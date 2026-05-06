import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sailogger719/constant/colors.dart';
import 'package:wifi_iot/wifi_iot.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final String host = '172.24.1.1';
  final int port = 22;
  final String username = 'skyflix';
  final String password = 'byskyreach';

  bool _isRunning = false;
  String _runningMode = '';
  double _progress = 0;
  String _activeStep = '-';
  String _status = 'Idle';
  String _ssid = '-';
  String _wifiIp = '-';
  bool _isWifiConnected = false;

  final Map<String, String> _results = {};
  final List<String> _resultOrder = const [
    'OS DateTime',
    'Uptime',
    'FailedSMS Top10',
    'FailedSMS Bottom10',
    'FailedSMS Count',
    'IOT-Service',
    'RPM1',
    'RPM2',
    'RPM3',
    'RPM4',
    'Exhaust1',
    'Exhaust2',
    'GPS Raw',
    'GPS Parsed',
    'SAT Mode',
    'SAT Status',
    'iTech.log',
    'Date Update',
    'THEREACH Process',
  ];

  bool _isDeviceWifiSsid(String ssid) {
    final normalized = ssid.replaceAll('"', '').trim().toUpperCase();
    return normalized.contains('SAILOGGER') || normalized.contains('SAILINK');
  }

  bool _isDeviceSubnetIp(String ip) {
    final normalized = ip.trim();
    return normalized.startsWith('172.24.1.');
  }

  Future<bool> _isDeviceReachable() async {
    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _getCurrentWifi() async {
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
        _ssid = normalized.isEmpty ? '-' : normalized;
        _wifiIp = (wifiIp == null || wifiIp.isEmpty) ? '-' : wifiIp;
        _isWifiConnected = bySsid || bySubnet || byIp;
      });
    } catch (_) {
      final byIp = await _isDeviceReachable();
      setState(() {
        _ssid = '-';
        _wifiIp = '-';
        _isWifiConnected = byIp;
      });
    }
  }

  Future<String> _run(SSHClient client, String cmd) async {
    final bytes = await client.run(cmd);
    try {
      return utf8.decode(bytes, allowMalformed: true).trim();
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true).trim();
    }
  }

  String _parseConnectionStatusFromJson(String raw) {
    try {
      final parsed = jsonDecode(raw);
      final data = (parsed is Map && parsed['data'] is Map)
          ? parsed['data'] as Map
          : (parsed is Map ? parsed : <String, dynamic>{});
      final status = (data['status'] ?? '').toString().trim();
      if (status.toLowerCase() == 'notdefined' || status.isEmpty) {
        return 'DISCONNECTED';
      }
      return 'CONNECTED';
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  String _parseSatStatusFromJson(String raw) {
    try {
      final parsed = jsonDecode(raw);
      final data = (parsed is Map && parsed['data'] is Map)
          ? parsed['data'] as Map
          : (parsed is Map ? parsed : <String, dynamic>{});
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'none' || status.isEmpty) {
        return 'DISCONNECTED';
      }
      return 'CONNECTED';
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  String _formatGpsDateTimeLikeOs(String raw) {
    final s = raw.trim();
    if (s.length != 14) return raw;
    try {
      final year = int.parse(s.substring(0, 4));
      final month = int.parse(s.substring(4, 6));
      final day = int.parse(s.substring(6, 8));
      final hour = int.parse(s.substring(8, 10));
      final minute = int.parse(s.substring(10, 12));
      final second = int.parse(s.substring(12, 14));
      final dt = DateTime(year, month, day, hour, minute, second);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final wd = weekdays[dt.weekday - 1];
      final mo = months[dt.month - 1];
      final dd = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final ss = dt.second.toString().padLeft(2, '0');
      return '$wd $mo $dd $hh:$mm:$ss WIB ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _runDiagnostic({required bool quick}) async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _runningMode = quick ? 'quick' : 'full';
      _progress = 0;
      _activeStep = 'Connecting SSH...';
      _status = quick ? 'Running Quick Check' : 'Running Full Diagnostic';
      _results.clear();
    });

    SSHClient? client;
    try {
      client = SSHClient(
        await SSHSocket.connect(host, port, timeout: const Duration(seconds: 5)),
        username: username,
        onPasswordRequest: () => password,
      );

      final steps = <Map<String, String>>[
        {'title': 'OS DateTime', 'cmd': 'date'},
        {'title': 'Uptime', 'cmd': 'uptime'},
      ];

      if (!quick) {
        steps.addAll([
          {'title': 'FailedSMS Top10', 'cmd': 'head -n 10 /var/Python/log/FailedSMS.log'},
          {'title': 'FailedSMS Bottom10', 'cmd': 'tail -n 10 /var/Python/log/FailedSMS.log'},
          {'title': 'FailedSMS Count', 'cmd': 'wc -l /var/Python/log/FailedSMS.log'},
          {'title': 'IOT-Service', 'cmd': 'cat /var/Python/Configs/IOT-Service.SKY'},
          {'title': 'RPM1', 'cmd': 'cat /var/Python/Status/RPM1.json'},
          {'title': 'RPM2', 'cmd': 'cat /var/Python/Status/RPM2.json'},
          {'title': 'RPM3', 'cmd': 'cat /var/Python/Status/RPM3.json'},
          {'title': 'RPM4', 'cmd': 'cat /var/Python/Status/RPM4.json'},
          {'title': 'Exhaust1', 'cmd': 'cat /var/Python/Status/Exhaust1.json'},
          {'title': 'Exhaust2', 'cmd': 'cat /var/Python/Status/Exhaust2.json'},
          {'title': 'GPS Raw', 'cmd': 'cat /var/Python/GPS/SAILINK.json'},
          {'title': 'SAT Mode', 'cmd': 'cat /var/Python/Configs/Comm-NET.SKY'},
          {'title': 'SAT Status', 'cmd': '__SAT_STATUS__'},
          {'title': 'iTech.log', 'cmd': 'tail -n 50 /var/Python/iTech.log'},
          {'title': 'THEREACH Process', 'cmd': 'ps -ax | grep THEREACH'},
        ]);
      }

      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        final title = step['title']!;
        final cmd = step['cmd']!;
        setState(() {
          _activeStep = 'Step ${i + 1}/${steps.length}: $title';
          _progress = ((i) / steps.length) * 100;
        });
        String out;
        if (cmd == '__SAT_STATUS__') {
          final satMode = (_results['SAT Mode'] ?? '').toLowerCase();
          if (satMode.contains('iridium')) {
            out = await _run(client, 'cat /var/Python/Status/Iridium.json');
          } else if (satMode.contains('thuraya')) {
            out = await _run(client, 'cat /var/Python/Status/Thuraya.json');
          } else {
            out = 'Unknown SAT mode';
          }
        } else {
          out = await _run(client, cmd);
        }
        _results[title] = out.isEmpty ? '(empty)' : out;

        if (title == 'RPM1' ||
            title == 'RPM2' ||
            title == 'RPM3' ||
            title == 'RPM4' ||
            title == 'Exhaust1' ||
            title == 'Exhaust2') {
          _results['$title Status'] = _parseConnectionStatusFromJson(out);
        }

        if (title == 'GPS Raw') {
          try {
            final data = jsonDecode(out);
            final gps = (data is Map && data['data'] is Map)
                ? data['data'] as Map
                : (data is Map ? data : <String, dynamic>{});
            final dt = gps['datetimeGMTplus7'] ?? gps['datetime'] ?? gps['time'] ?? '-';
            final lat = gps['latitude'] ?? '-';
            final latHem = gps['latitudeHemisphere'] ?? '';
            final lng = gps['longitude'] ?? '-';
            final lngHem = gps['longitudeHemisphere'] ?? '';
            final dtFormatted = _formatGpsDateTimeLikeOs(dt.toString());
            _results['GPS Parsed'] =
                'datetime: $dtFormatted\nlatitude: $lat $latHem\nlongitude: $lng $lngHem';
          } catch (_) {
            _results['GPS Parsed'] = 'Failed parsing GPS JSON';
          }
        }
      }

      if (!quick) {
        _results['SAT Status Summary'] =
            _parseSatStatusFromJson(_results['SAT Status'] ?? '');
      }

      setState(() {
        _progress = 100;
        _activeStep = 'Completed';
        _status = 'Done';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      client?.close();
      setState(() {
        _isRunning = false;
        _runningMode = '';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentWifi();
  }

  Future<void> _showSetDateDialog() async {
    DateTime selected = DateTime.now();
    final v = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set OS Date & Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selected,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    setDialogState(() {
                      selected = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        selected.hour,
                        selected.minute,
                        0,
                      );
                    });
                  },
                  child: Text(
                    'Date: ${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selected.hour,
                      decoration: const InputDecoration(labelText: 'Hour'),
                      items: List.generate(
                        24,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.toString().padLeft(2, '0')),
                        ),
                      ),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          selected = DateTime(
                            selected.year,
                            selected.month,
                            selected.day,
                            v,
                            selected.minute,
                            0,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selected.minute,
                      decoration: const InputDecoration(labelText: 'Minute'),
                      items: List.generate(
                        60,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.toString().padLeft(2, '0')),
                        ),
                      ),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          selected = DateTime(
                            selected.year,
                            selected.month,
                            selected.day,
                            selected.hour,
                            v,
                            0,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () {
                  final formatted =
                      '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')} ${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}:00';
                  Navigator.pop(context, formatted);
                },
                child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (v == null || v.isEmpty) return;

    SSHClient? client;
    try {
      client = SSHClient(
        await SSHSocket.connect(host, port, timeout: const Duration(seconds: 5)),
        username: username,
        onPasswordRequest: () => password,
      );
      final out = await _run(client, 'date -s "$v" && date');
      setState(() {
        _results['Date Update'] = out;
      });
    } catch (e) {
      setState(() {
        _results['Date Update'] = 'Failed: $e';
      });
    } finally {
      client?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Device Diagnostic',
          style: TextStyle(color: slapp_color.primary),
        ),
        iconTheme: IconThemeData(color: slapp_color.primary),
        backgroundColor: slapp_color.fifthiary.withOpacity(0.2),
      ),
      backgroundColor: slapp_color.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: slapp_color.fifthiary.withOpacity(0.12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Wi-Fi : ${(_ssid.isEmpty) ? "-" : _ssid}\nIP : $_wifiIp',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: slapp_color.black_text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isWifiConnected ? 'CONNECTED' : 'NOT CONNECTED',
                  style: TextStyle(
                    color: _isWifiConnected ? slapp_color.success : slapp_color.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                IconButton(
                  onPressed: _getCurrentWifi,
                  icon: Icon(Icons.refresh, color: slapp_color.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (_progress / 100).clamp(0, 1),
                  minHeight: 8,
                  color: slapp_color.primary,
                  backgroundColor: slapp_color.fifthiary.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progress: ${_progress.toStringAsFixed(0)}%',
                  style: TextStyle(color: slapp_color.black_text, fontWeight: FontWeight.bold),
                ),
                Text('Status: $_status', style: TextStyle(color: slapp_color.black_text)),
                Text('Step: $_activeStep', style: TextStyle(color: slapp_color.black_text)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (states) {
                          if (_isRunning && _runningMode == 'full') {
                            return slapp_color.success;
                          }
                          if (states.contains(MaterialState.disabled)) {
                            return slapp_color.sixtiary;
                          }
                          return slapp_color.primary;
                        },
                      ),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(slapp_color.white),
                      elevation: MaterialStateProperty.all<double>(0),
                    ),
                    onPressed: _isRunning ? null : () => _runDiagnostic(quick: false),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRunning && _runningMode == 'full')
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: slapp_color.white,
                              ),
                            ),
                          if (_isRunning && _runningMode == 'full')
                            const SizedBox(width: 8),
                          const Text('Run Full Diagnostic'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: ButtonStyle(
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      side: MaterialStateProperty.resolveWith<BorderSide>(
                        (states) => BorderSide(
                          color: states.contains(MaterialState.disabled)
                              ? slapp_color.sixtiary
                              : slapp_color.primary,
                        ),
                      ),
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (states) => states.contains(MaterialState.disabled)
                            ? slapp_color.sixtiary
                            : slapp_color.white,
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>(
                        (states) => states.contains(MaterialState.disabled)
                            ? slapp_color.white
                            : slapp_color.primary,
                      ),
                    ),
                    onPressed: _isRunning ? null : _showSetDateDialog,
                    child: const Text('Set OS Date & Time'),
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: _resultOrder
                  .where((k) => _results.containsKey(k))
                  .map(
                    (k) => ExpansionTile(
                      iconColor: slapp_color.primary,
                      collapsedIconColor: slapp_color.primary,
                      collapsedBackgroundColor: slapp_color.fifthiary.withOpacity(0.08),
                      backgroundColor: slapp_color.fifthiary.withOpacity(0.15),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              k,
                              style: TextStyle(
                                color: slapp_color.black_text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (k == 'SAT Status' && _results['SAT Status Summary'] != null)
                            Text(
                              _results['SAT Status Summary']!,
                              style: TextStyle(
                                color: (_results['SAT Status Summary'] == 'CONNECTED')
                                    ? slapp_color.success
                                    : slapp_color.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          if ((k == 'RPM1' ||
                                  k == 'RPM2' ||
                                  k == 'RPM3' ||
                                  k == 'RPM4' ||
                                  k == 'Exhaust1' ||
                                  k == 'Exhaust2') &&
                              _results['$k Status'] != null)
                            Text(
                              _results['$k Status']!,
                              style: TextStyle(
                                color: (_results['$k Status'] == 'CONNECTED')
                                    ? slapp_color.success
                                    : slapp_color.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: Colors.black,
                          child: SelectableText(
                            _results[k] ?? '-',
                            style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
