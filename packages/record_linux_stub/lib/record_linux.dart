import 'dart:typed_data';
import 'package:record_platform_interface/record_platform_interface.dart';

/// Stub implementation of RecordLinux.
/// This app targets Android/iOS only. This stub exists to satisfy
/// the Dart compiler which compiles all platform implementations.
class RecordLinux extends RecordPlatform {
  static void registerWith() {
    RecordPlatform.instance = RecordLinux();
  }

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async {
    return Amplitude(current: -160.0, max: -160.0);
  }

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    return false;
  }

  @override
  Future<bool> isEncoderSupported(String recorderId, AudioEncoder encoder) async {
    return false;
  }

  @override
  Future<bool> isPaused(String recorderId) async {
    return false;
  }

  @override
  Future<bool> isRecording(String recorderId) async {
    return false;
  }

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<void> start(String recorderId, RecordConfig config, {required String path}) async {}

  @override
  Future<Stream<Uint8List>> startStream(String recorderId, RecordConfig config) async {
    return const Stream.empty();
  }

  @override
  Future<String?> stop(String recorderId) async {
    return null;
  }

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async {
    return [];
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) {
    return const Stream.empty();
  }
}
