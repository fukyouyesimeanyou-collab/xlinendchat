import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'waku_bindings.dart';

class WakuService {
  late final WakuBindings _bindings;
  Pointer<Void>? _nodeContext;
  
  // Stream for incoming Waku events (new messages, peer changes, etc.)
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;
  
  NativeCallable<WakuCallBackC>? _eventCallable;

  WakuService(String libPath) {
    _bindings = WakuBindings(libPath);
  }

  Future<void> initialize({String configJson = "{}"}) async {
    final completer = Completer<void>();
    late final NativeCallable<WakuCallBackC> nativeCallable;
    
    nativeCallable = NativeCallable<WakuCallBackC>.listener((int retCode, Pointer<Utf8> msg, Pointer<Void> userData) {
      final message = msg.toDartString();
      if (!completer.isCompleted) {
        completer.completeError(Exception("Waku Init Error (via callback): $message"));
      }
      nativeCallable.close();
    });

    final configPtr = configJson.toNativeUtf8();
    try {
      _nodeContext = _bindings.wakuNew(configPtr, nativeCallable.nativeFunction, nullptr);
      if (_nodeContext != null && _nodeContext != nullptr) {
        nativeCallable.close();
        _setupEventCallback(); // Automatically set up event listener
        return; 
      }
    } catch (e) {
      nativeCallable.close();
      rethrow;
    } finally {
      malloc.free(configPtr);
    }

    return completer.future.timeout(Duration(seconds: 5), onTimeout: () {
      nativeCallable.close();
      throw TimeoutException("Waku initialization failed and timed out");
    });
  }

  void _setupEventCallback() {
    if (_nodeContext == null) return;
    
    _eventCallable = NativeCallable<WakuCallBackC>.listener((int retCode, Pointer<Utf8> msg, Pointer<Void> userData) {
      final message = msg.toDartString();
      _eventController.add(message);
    });
    
    _bindings.wakuSetEventCallback(_nodeContext!, _eventCallable!.nativeFunction);
  }

  Future<void> start() async {
    if (_nodeContext == null) throw Exception("Node not initialized");

    final completer = Completer<void>();
    late final NativeCallable<WakuCallBackC> nativeCallable;

    nativeCallable = NativeCallable<WakuCallBackC>.listener((int retCode, Pointer<Utf8> msg, Pointer<Void> userData) {
      if (!completer.isCompleted) {
        completer.completeError(Exception("Waku Start Error (via callback): ${msg.toDartString()}"));
      }
      nativeCallable.close();
    });

    final result = _bindings.wakuStart(_nodeContext!, nativeCallable.nativeFunction, nullptr);
    if (result == 0) {
      nativeCallable.close();
      return;
    }

    return completer.future.timeout(Duration(seconds: 5), onTimeout: () {
      nativeCallable.close();
      throw TimeoutException("Waku start failed (Code $result)");
    });
  }

  /// Subscribe to a Waku Relay topic
  Future<void> relaySubscribe(String contentTopic) async {
    if (_nodeContext == null) return;
    
    // Simplest filter JSON for relay subscribe
    final filterJson = jsonEncode({"contentTopics": [contentTopic]});
    final filterPtr = filterJson.toNativeUtf8();
    
    try {
      _bindings.wakuRelaySubscribe(_nodeContext!, filterPtr, nullptr, nullptr);
    } finally {
      malloc.free(filterPtr);
    }
  }

  /// Publish a message via Waku Relay
  Future<void> relayPublish(String contentTopic, List<int> payload, {int ms = 0}) async {
    if (_nodeContext == null) return;
    
    final messageJson = jsonEncode({
      "payload": base64Encode(payload),
      "contentTopic": contentTopic,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
    
    final msgPtr = messageJson.toNativeUtf8();
    final topicPtr = "".toNativeUtf8(); // Relay topic can be empty string if message has contentTopic
    
    try {
      _bindings.wakuRelayPublish(_nodeContext!, msgPtr, topicPtr, ms, nullptr, nullptr);
    } finally {
      malloc.free(msgPtr);
      malloc.free(topicPtr);
    }
  }

  bool isStarted() {
    if (_nodeContext == null) return false;
    return _bindings.wakuIsStarted(_nodeContext!) != 0;
  }

  Future<void> stop() async {
    if (_nodeContext == null) return;

    final completer = Completer<void>();
    late final NativeCallable<WakuCallBackC> nativeCallable;

    nativeCallable = NativeCallable<WakuCallBackC>.listener((int retCode, Pointer<Utf8> msg, Pointer<Void> userData) {
      completer.complete();
      nativeCallable.close();
    });

    final result = _bindings.wakuStop(_nodeContext!, nativeCallable.nativeFunction, nullptr);
    if (result == 0) {
      nativeCallable.close();
    } else {
       await completer.future.timeout(Duration(seconds: 5), onTimeout: () {
        nativeCallable.close();
      });
    }
    
    _eventCallable?.close();
    _eventController.close();
  }
}
