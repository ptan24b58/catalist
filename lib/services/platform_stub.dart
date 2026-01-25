// Stub file for web platform - provides empty implementations
// This file is used when compiling for web where dart:io is not available

class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
}

class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<String> readAsString() async => '';
  Future<void> delete() async {}
}
