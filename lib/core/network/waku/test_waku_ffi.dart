import 'dart:io';
import 'waku_service.dart';

void main() async {
  print("--- Waku FFI Smoke Test ---");
  
  // Path to libwaku.so (absolute path for testing in container)
  final libPath = "/home/hbj/mvplab-projects/xlinendchat/lib/core/network/waku/native/libwaku.so";
  
  if (!File(libPath).existsSync()) {
    print("Error: libwaku.so not found at $libPath");
    exit(1);
  }

  final waku = WakuService(libPath);

  try {
    print("Initializing Waku node...");
    await waku.initialize(configJson: '{"host":"0.0.0.0", "port":0}');
    print("Waku Node Context created!");

    print("Starting Waku node...");
    await waku.start();
    print("Waku Node started successfully!");

    final started = waku.isStarted();
    print("Is Waku Node started? $started");

    if (started) {
      print("SUCCESS: Native bridge foundation is solid.");
    } else {
      print("FAILURE: Node reported as not started.");
    }

    print("Stopping Waku node...");
    await waku.stop();
    print("Waku Node stopped.");

    exit(0);
  } catch (e) {
    print("ERROR during Waku FFI test: $e");
    exit(1);
  }
}
