// Stub file for web platform - provides empty implementations
// This file is used when compiling for web where dart:io is not available

/// Platform stub for web builds
class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
}

/// File stub for web builds
class File {
  final String path;
  File(this.path);

  Future<bool> exists() async => false;
  Future<String> readAsString() async => '';
  Future<void> delete() async {}
}
