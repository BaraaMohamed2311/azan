import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('DeviceOrientationEvent')
external JSObject? get _deviceOrientationCtor;

Stream<double> webHeadingStream() {
  late StreamController<double> controller;
  web.EventListener? listener;

  void attach() {
    listener = ((web.DeviceOrientationEvent event) {
      final alpha = event.alpha;
      if (alpha != null && !controller.isClosed) {
        controller.add((360 - alpha + 360) % 360);
      }
    }).toJS;
    web.window.addEventListener('deviceorientation', listener!);
  }

  void detach() {
    if (listener != null) {
      web.window.removeEventListener('deviceorientation', listener!);
      listener = null;
    }
  }

  controller = StreamController<double>(
    onListen: () async {
      // iOS Safari requires an explicit permission request before the sensor
      // delivers events.
      final ctor = _deviceOrientationCtor;
      if (ctor != null) {
        final requestPermission = ctor.getProperty('requestPermission'.toJS);
        if (requestPermission != null &&
            requestPermission.typeofEquals('function')) {
          try {
            final promise = (requestPermission as JSFunction)
                .callAsFunction(ctor) as JSPromise<JSString>;
            final result = await promise.toDart;
            if (result.toDart != 'granted' && !controller.isClosed) {
              controller.addError('permission');
              return;
            }
          } catch (_) {
            if (!controller.isClosed) controller.addError('permission');
            return;
          }
        }
      }
      attach();
    },
    onCancel: detach,
  );
  return controller.stream;
}
