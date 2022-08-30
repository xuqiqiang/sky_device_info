import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:sky_device_info/beans.dart';
import 'package:sky_device_info/sky_device_info.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _skyDeviceInfoPlugin = SkyDeviceInfo();
  String? _deviceInfo;
  String? _networkInfo;

  @override
  void initState() {
    super.initState();
    loadDeviceInfo();
    getIntranetIp();
  }

  @override
  void dispose() {
    super.dispose();
    _skyDeviceInfoPlugin.release();
  }

  String formatJson(Object? object) {
    return jsonEncode(object)
        .replaceAll('{', '{\n')
        .replaceAll('}', '\n}')
        .replaceAll(',', ',\n');
  }

  loadDeviceInfo() async {
    DeviceInfo? deviceInfo = await _skyDeviceInfoPlugin.loadDeviceInfo();
    setState(() {
      _deviceInfo = formatJson(deviceInfo ?? 'Unknown');
    });
    _skyDeviceInfoPlugin.onNetworkChanged = (NetworkInfo? info) {
      NetworkInfo? networkInfo = _skyDeviceInfoPlugin.networkInfo;
      setState(() {
        _networkInfo = formatJson(networkInfo ?? 'Unknown');
      });
    };
  }

  Future<String?> getIntranetIp() async {
    String? ip;
    for (var interface in await NetworkInterface.list()) {
      SkyDeviceInfo.log('interface ${interface.name} ${interface.index}');
      for (var addr in interface.addresses) {
        SkyDeviceInfo.log(
            'address ${addr.address} ${addr.host} ${addr.isLoopback} ${addr.isLinkLocal} ${addr.isMulticast}');
        if (addr.address.startsWith('192.') ||
            addr.address.startsWith('10.') ||
            addr.address.startsWith('172.')) ip = addr.address;
      }
    }
    return ip;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
          padding: const EdgeInsets.all(20),
          child: Center(
            child:
                Text('DeviceInfo: $_deviceInfo\nNetworkInfo: $_networkInfo'),
          ),
        ),
      ),
    );
  }
}
