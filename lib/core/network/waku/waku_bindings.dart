import 'dart:ffi';
import 'package:ffi/ffi.dart';

// C Types Definitions
typedef WakuCallBackC = Void Function(Int32 retCode, Pointer<Utf8> msg, Pointer<Void> userData);
typedef WakuCallBackDart = void Function(int retCode, Pointer<Utf8> msg, Pointer<Void> userData);

typedef WakuNewC = Pointer<Void> Function(Pointer<Utf8> configJSON, Pointer<NativeFunction<WakuCallBackC>> cb, Pointer<Void> userData);
typedef WakuNewDart = Pointer<Void> Function(Pointer<Utf8> configJSON, Pointer<NativeFunction<WakuCallBackC>> cb, Pointer<Void> userData);

typedef WakuStartC = Int32 Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> onErr, Pointer<Void> userData);
typedef WakuStartDart = int Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> onErr, Pointer<Void> userData);

typedef WakuStopC = Int32 Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> onErr, Pointer<Void> userData);
typedef WakuStopDart = int Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> onErr, Pointer<Void> userData);

typedef WakuIsStartedC = Int32 Function(Pointer<Void> ctx);
typedef WakuIsStartedDart = int Function(Pointer<Void> ctx);

typedef WakuFreeC = Int32 Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> onErr, Pointer<Void> userData);
typedef WakuFreeDart = int Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> onErr, Pointer<Void> userData);

typedef WakuSetEventCallbackC = Void Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> cb);
typedef WakuSetEventCallbackDart = void Function(Pointer<Void> ctx, Pointer<NativeFunction<WakuCallBackC>> cb);

typedef WakuRelayPublishC = Int32 Function(Pointer<Void> ctx, Pointer<Utf8> messageJSON, Pointer<Utf8> topic, Int32 ms, Pointer<NativeFunction<WakuCallBackC>> cb, Pointer<Void> userData);
typedef WakuRelayPublishDart = int Function(Pointer<Void> ctx, Pointer<Utf8> messageJSON, Pointer<Utf8> topic, int ms, Pointer<NativeFunction<WakuCallBackC>> cb, Pointer<Void> userData);

typedef WakuRelaySubscribeC = Int32 Function(Pointer<Void> ctx, Pointer<Utf8> filterJSON, Pointer<NativeFunction<WakuCallBackC>> cb, Pointer<Void> userData);
typedef WakuRelaySubscribeDart = int Function(Pointer<Void> ctx, Pointer<Utf8> filterJSON, Pointer<NativeFunction<WakuCallBackC>> cb, Pointer<Void> userData);

class WakuBindings {
  late final DynamicLibrary _lib;

  late final WakuNewDart wakuNew;
  late final WakuStartDart wakuStart;
  late final WakuStopDart wakuStop;
  late final WakuIsStartedDart wakuIsStarted;
  late final WakuFreeDart wakuFree;
  late final WakuSetEventCallbackDart wakuSetEventCallback;
  late final WakuRelayPublishDart wakuRelayPublish;
  late final WakuRelaySubscribeDart wakuRelaySubscribe;

  WakuBindings(String path) {
    _lib = DynamicLibrary.open(path);
    _initialize();
  }

  void _initialize() {
    wakuNew = _lib.lookupFunction<WakuNewC, WakuNewDart>('waku_new');
    wakuStart = _lib.lookupFunction<WakuStartC, WakuStartDart>('waku_start');
    wakuStop = _lib.lookupFunction<WakuStopC, WakuStopDart>('waku_stop');
    wakuIsStarted = _lib.lookupFunction<WakuIsStartedC, WakuIsStartedDart>('waku_is_started');
    wakuFree = _lib.lookupFunction<WakuFreeC, WakuFreeDart>('waku_free');
    wakuSetEventCallback = _lib.lookupFunction<WakuSetEventCallbackC, WakuSetEventCallbackDart>('waku_set_event_callback');
    wakuRelayPublish = _lib.lookupFunction<WakuRelayPublishC, WakuRelayPublishDart>('waku_relay_publish');
    wakuRelaySubscribe = _lib.lookupFunction<WakuRelaySubscribeC, WakuRelaySubscribeDart>('waku_relay_subscribe');
  }
}
