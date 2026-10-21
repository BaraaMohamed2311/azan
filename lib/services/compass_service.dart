import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_compass/flutter_compass.dart';
import 'compass_web_stub.dart'
    if (dart.library.js_interop) 'compass_web.dart' as compass_web;

/// Unified heading stream (degrees clockwise from true north).
///
/// - Native (Android/iOS): flutter_compass sensor stream.
/// - Web: DeviceOrientationEvent, mirroring the original app's browser path
///   (heading = (360 - alpha) % 360).
class CompassService {
  static Stream<double> headingStream() {
    if (kIsWeb) {
      return compass_web.webHeadingStream();
    }
    final controller = StreamController<double>();
    StreamSubscription<CompassEvent>? sub;
    controller.onListen = () {
      sub = FlutterCompass.events?.listen(
        (event) {
          final heading = event.heading ?? -1;
          if (heading >= 0 && !controller.isClosed) {
            controller.add(heading);
          }
        },
        onError: (Object _) {
          if (!controller.isClosed) controller.addError('sensor');
        },
        cancelOnError: false,
      );
      if (sub == null && !controller.isClosed) {
        controller.addError('unavailable');
      }
    };
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }
}
