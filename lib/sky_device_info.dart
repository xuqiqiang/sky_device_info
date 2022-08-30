import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:sky_device_info/beans.dart';
import 'package:network_info_plus/network_info_plus.dart' as network_info_plus;

typedef OnNetworkChanged = Function(NetworkInfo?);

class SkyDeviceInfo {
  final _channel = const MethodChannel('sky_device_info');
  Function(DeviceInfo?)? _onDeviceInfo;
  DeviceInfo? _deviceInfo;
  NetworkInfo? _networkInfo;
  String? _networkInfoJson;
  final List<OnNetworkChanged> _onNetworkCallbackList = [];
  dynamic _networkSubscription;
  bool? _loadNetworkInfo;

  static log(Object? object) {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    if (!inDebugMode) return;
    if (object == null) return;
    // ignore: avoid_print
    print('$object');
  }

  SkyDeviceInfo._privateConstructor();

  static final SkyDeviceInfo _instance = SkyDeviceInfo._privateConstructor();

  factory SkyDeviceInfo() {
    return _instance;
  }

  NetworkInfo? get networkInfo => _networkInfo;

  addNetworkCallback(OnNetworkChanged value) {
    _onNetworkCallbackList.add(value);
    if (_networkInfo != null) {
      value.call(_networkInfo);
    }
  }

  removeNetworkCallback(OnNetworkChanged value) {
    _onNetworkCallbackList.remove(value);
  }

  onNetworkChanged(NetworkInfo? networkInfo) {
    for (OnNetworkChanged item in _onNetworkCallbackList) {
      item.call(networkInfo);
    }
  }

  Future<NetworkInfo> readNetworkInfoByDart() async {
    List<NetworkAdapter> list = [];
    for (var interface in await NetworkInterface.list()) {
      // log('interface ${interface.name} ${interface.index}');
      for (var addr in interface.addresses) {
        // log('address ${addr.address} ${addr.host} ${addr.isLoopback}'
        //     ' ${addr.isLinkLocal} ${addr.isMulticast}');
        if (addr.address.startsWith('192.') ||
            addr.address.startsWith('10.') ||
            addr.address.startsWith('172.')) {
          NetworkAdapter adapter = NetworkAdapter(
              ipAddress: addr.address,
              connectionName: interface.name,
              index: interface.index);
          list.add(adapter);
        }
      }
    }
    return NetworkInfo(networkAdapters: list);
  }

  Future<NetworkInfo> _readNetworkInfo(connectivityResult) async {
    if (connectivityResult == ConnectivityResult.wifi) {
      final info = network_info_plus.NetworkInfo();
      // var wifiBSSID = await info.getWifiBSSID(); // 11:22:33:44:55:66
      String? ssid = await info.getWifiName();
      if (ssid != null &&
          ssid.length > 2 &&
          ssid.startsWith('"') &&
          ssid.endsWith('"')) {
        ssid = ssid.substring(1, ssid.length - 1);
      }
      NetworkAdapter adapter = NetworkAdapter(
          ssid: ssid,
          ipAddress: await info.getWifiIP(),
          ipAddressIPv6: await info.getWifiIPv6(),
          ipMaskAddress: await info.getWifiSubmask(),
          gatewayIpAddress: await info.getWifiGatewayIP(),
          ipBroadcast: await info.getWifiBroadcast(),
          index: 0);
      return NetworkInfo(networkAdapters: [adapter]);
    }
    return await readNetworkInfoByDart();
  }

  Future<DeviceInfo?> loadDeviceInfo({bool loadNetworkInfo = true}) async {
    if (_deviceInfo != null) return _deviceInfo!;
    _loadNetworkInfo = loadNetworkInfo;
    if (!Platform.isWindows) {
      String json = await _channel.invokeMethod('loadDeviceInfo');
      log('deviceInfo $json');
      _deviceInfo = DeviceInfo.fromJson(jsonDecode(json));

      if (loadNetworkInfo) {
        var connectivityResult = await Connectivity().checkConnectivity();
        log('connectivityResult $connectivityResult');
        _networkInfo = await _readNetworkInfo(connectivityResult);
        onNetworkChanged(_networkInfo);

        _networkSubscription = Connectivity()
            .onConnectivityChanged
            .listen((ConnectivityResult result) async {
          _networkInfo = await _readNetworkInfo(result);
          onNetworkChanged(_networkInfo);
        });
      }

      return _deviceInfo;
    }
    if (_onDeviceInfo != null) return null;
    Completer<DeviceInfo?> completer = Completer<DeviceInfo?>();
    _onDeviceInfo = (result) => completer.complete(result);

    _channel.setMethodCallHandler((MethodCall call) async {
      // print("playerPlugin method=${call.method} arguments=${call.arguments}");
      if (call.method == 'onDeviceInfo') {
        log('deviceInfo ${_onDeviceInfo != null} ${call.arguments}');
        DeviceInfo deviceInfo = DeviceInfo.fromJson(jsonDecode(call.arguments));
        _deviceInfo = deviceInfo;
        if (_loadNetworkInfo != true) {
          _onDeviceInfo?.call(deviceInfo);
          _onDeviceInfo = null;
        }
      } else if (call.method == 'onNetworkInfo') {
        if (_networkInfoJson != call.arguments) {
          _networkInfoJson = call.arguments;
          log('loadNetworkInfo ${call.arguments}');
          NetworkInfo networkInfo =
              NetworkInfo.fromJson(jsonDecode(call.arguments));
          _networkInfo = networkInfo;
          onNetworkChanged(_networkInfo);
        }
        if (_loadNetworkInfo == true) {
          _onDeviceInfo?.call(_deviceInfo);
          _onDeviceInfo = null;
        }
      }
    });

    final Map<String, dynamic> arguments = {
      'loadNetworkInfo': loadNetworkInfo,
    };
    _channel.invokeMethod('loadDeviceInfo', arguments);
    return completer.future;
  }

  release() {
    _channel.setMethodCallHandler(null);
    if (Platform.isWindows) {
      _channel.invokeMethod('release');
    }
    _networkSubscription?.cancel();
    _onNetworkCallbackList.clear();
    _deviceInfo = null;
    _networkInfo = null;
    _networkInfoJson = null;
  }
}
