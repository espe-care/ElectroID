// Stub para Web: compila pero no hay NFC real
// Define los mismos nombres que usas en main.dart.

enum NFCAvailability { not_supported, disabled, available }

class _WebTag {
  final bool? ndefAvailable;
  const _WebTag({this.ndefAvailable = false});
}

class FlutterNfcKit {
  static Future<NFCAvailability> get nfcAvailability async =>
      NFCAvailability.not_supported;

  static Future<_WebTag> poll({Duration? timeout, String? iosAlertMessage}) async =>
      const _WebTag(ndefAvailable: false);

  static Future<List<dynamic>> readNDEFRecords({bool cached = false}) async =>
      const <dynamic>[];

  static Future<void> finish() async {}
}
