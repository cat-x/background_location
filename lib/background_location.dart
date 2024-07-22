import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/services.dart';

import 'package:background_location/background_callback.dart';

typedef LocationCallback = void Function(List<Location> value);
typedef OptLocationCallback = void Function(Location? value);

enum LocationPriority {
  /// The best level of accuracy available.
  priorityHighAccuracy,
  // Accurate to within one hundred meters.
  priorityBalancedPowerAccuracy,
  // Accurate to within ten meters of the desired target.
  priorityLowPower,
  // The level of accuracy used when an app isn’t authorized for full accuracy location data.
  priorityNoPower,
}

/// BackgroundLocation plugin to get background
/// lcoation updates in iOS and Android
class BackgroundLocation {
  // The channel to be used for communication.
  // This channel is also referenced inside both iOS and Abdroid classes
  static final MethodChannel _channel = const MethodChannel('com.almoullim.background_location/methods')..setMethodCallHandler((MethodCall methodCall) async {
    switch(methodCall.method) {
      case 'location':
        var locationData = methodCall.arguments as Map;
        locationCallbackStream?.add(Location.fromJson(locationData));
        break;
      case 'notificationAction':
        var callback = notificationActionCallback;
        var response = methodCall.arguments as Map;
        var location = response[argLocation] as Map;
        if (callback != null) {
          callback(Location.fromJson(location));
        }
        break;
    }
  });

  static StreamController<Location>? locationCallbackStream;
  static OptLocationCallback? notificationActionCallback;

  /// Stop receiving location updates
  static Future<dynamic> stopLocationService() async {
    return await _channel.invokeMethod('stop_location_service');
  }

  /// Check if the location update service is running
  static Future<bool> isServiceRunning() async {
    var result = await _channel.invokeMethod('is_service_running');
    return result == true;
  }

  /// Start receiving location updated
  /// [wakelock] if you want to keep the device awake,and add the permission(android.permission.WAKE_LOCK) in the AndroidManifest.xml
  static Future<dynamic> startLocationService({
    bool startOnBoot = false,
    bool checkPermission = true,
    bool doubleCheckPermission = false,
    bool wakelock = false,
    int interval = 1000,
    int fastestInterval = 500,
    double distanceFilter = 0.0,
    bool forceAndroidLocationManager = false,
    LocationPriority priority = LocationPriority.priorityHighAccuracy,
    LocationCallback? backgroundCallback,
  }) async {
    if (checkPermission) {
      if (Platform.isAndroid) {
        //check permission
        var permissionStatus = await _channel.invokeMethod('check_permission');
        if (permissionStatus != true) {
          //request permission
          var permissionStatus = await _channel.invokeMethod('request_permission');
          if (permissionStatus != true) {
            return Future.error('Permission denied');
          }
        }
      }
    }
    var callbackHandle = 0;
    var locationCallback = 0;
    if (backgroundCallback != null) {
      callbackHandle = PluginUtilities.getCallbackHandle(callbackHandler)!.toRawHandle();
      try {
        locationCallback =
            PluginUtilities.getCallbackHandle(backgroundCallback)!
                .toRawHandle();
      } catch (ex, stack) {
        log('Error getting callback handle', error: ex, stackTrace: stack);
      }
    }

    return await _channel
        .invokeMethod('start_location_service', <String, dynamic>{
      'callbackHandle': callbackHandle,
      'locationCallback': locationCallback,
      'startOnBoot': startOnBoot,
      'checkPermission': doubleCheckPermission,
      'wakelock': wakelock,
      'interval': interval,
      'fastest_interval': fastestInterval,
      'priority': priority.index,
      'distance_filter': distanceFilter,
      'force_location_manager': forceAndroidLocationManager,
    });
  }

  ///Only for Android
  static Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod('check_permission') as bool? ?? false;
      } catch (e, s) {
        log("Error checking permission", error: e, stackTrace: s);
        return false;
      }
    } else {
      log("checkPermission ,but Platform is not Android");
      return true;
    }
  }

  ///Only for Android
  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod('request_permission') as bool? ?? false;
      } catch (e, s) {
        log("Error requesting permission", error: e, stackTrace: s);
        return false;
      }
    } else {
      log("requestPermission ,but Platform is not Android");
      return true;
    }
  }

  static Future<dynamic> setAndroidNotification({
    String? channelID,
    String? title,
    String? message,
    String? icon,
    String? actionText,
    OptLocationCallback? actionCallback,
  }) async {
    if (Platform.isAndroid) {
      var callback = 0;
      notificationActionCallback = actionCallback;
      if (actionCallback != null) {
        try {
          callback = PluginUtilities.getCallbackHandle(actionCallback)?.toRawHandle() ?? 0;
        } catch (ex, stack) {
          log('Error getting callback handle', error: ex, stackTrace: stack);
        }
      }

      var data = <String, dynamic>{
        'channelID': channelID,
        'title': title,
        'message': message,
        'icon': icon,
        'actionText': actionText,
        'actionCallback': callback,
      };

      try {
        return await _channel.invokeMethod('set_android_notification', data);
      } catch (ex, stack) {
        log('Error setting notification', error: ex, stackTrace: stack);

        return await const MethodChannel(backgroundChannelID).invokeMethod('set_android_notification', data);
      }

    } else {
      //return Promise.resolve();
    }
  }

  static Future<dynamic> setAndroidConfiguration(int interval) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod('set_configuration', <String, dynamic>{
        'interval': interval.toString(),
      });
    }
  }

  /// Get the current location once.
  Future<Location> getCurrentLocation() async {
    var completer = Completer<Location>();

    getLocationUpdates(completer.complete);

    return completer.future;
  }

  /// Register a function to receive location updates as long as the location
  /// service has started
  static StreamController<Location>? getLocationUpdates(void Function(Location) location) {
    if (locationCallbackStream?.isClosed == false) {
      locationCallbackStream?.close();
    }

    locationCallbackStream = StreamController();
    locationCallbackStream?.stream.listen(location);
    return locationCallbackStream;
  }
}

/// about the user current location
class Location {
  double latitude;
  double longitude;
  double altitude;
  double bearing;
  double accuracy;
  double speed;
  double time;
  bool isMock;

  Location({
    required this.longitude,
    required this.latitude,
    required this.altitude,
    required this.accuracy,
    required this.bearing,
    required this.speed,
    required this.time,
    required this.isMock,
  });

  factory Location.fromJson(Map<dynamic, dynamic> json) {
    bool isLocationMocked = Platform.isAndroid ? json['is_mock'] as bool : false;
    return Location(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      altitude: json['altitude'] as double,
      bearing: json['bearing'] as double,
      accuracy: json['accuracy'] as double,
      speed: json['speed'] as double,
      time: json['time'] as double,
      isMock: isLocationMocked,
    );
  }

  Map<String, Object> toMap() {
    var obj = {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'bearing': bearing,
      'accuracy': accuracy,
      'speed': speed,
      'time': time,
      'is_mock': isMock
    };
    return obj;
  }
}
