# sky_device_info
A Flutter plugin to get device info.


## Usage
Quick simple usage example:

#### Read network info
```dart
final _plugin = SkyDeviceInfo();

DeviceInfo? deviceInfo = await _plugin.loadDeviceInfo();
if (deviceInfo != null) {
  NetworkInfo? networkInfo = _plugin.networkInfo;
  if (networkInfo != null && networkInfo.networkAdapters.isNotEmpty) {
    String? ipAddress = networkInfo.networkAdapters.first.ipAddress;
    String? connectionName =
        networkInfo.networkAdapters.first.connectionName;
    String? ssid = networkInfo.networkAdapters.first.ssid;
  } else {
    // Network disconnected
  }
}
```