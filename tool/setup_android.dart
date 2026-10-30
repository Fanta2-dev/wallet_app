// Prépare le projet Android généré par `flutter create` :
//  - permission INTERNET (réseau)
//  - trafic HTTP en clair autorisé (le backend de dev est en http://, pas https://)
//
// Usage (depuis la racine du projet) :  dart run tool/setup_android.dart
import 'dart:io';

void main() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    stderr.writeln('AndroidManifest.xml introuvable. Lancez d\'abord : flutter create --platforms=android,ios --project-name wallet_app .');
    exit(1);
  }
  var xml = file.readAsStringSync();

  if (!xml.contains('android.permission.INTERNET')) {
    xml = xml.replaceFirstMapped(
      RegExp(r'<manifest[^>]*>'),
      (m) => '${m[0]}\n    <uses-permission android:name="android.permission.INTERNET"/>',
    );
    print('+ permission INTERNET ajoutée');
  }
  if (!xml.contains('usesCleartextTraffic')) {
    xml = xml.replaceFirst('<application', '<application\n        android:usesCleartextTraffic="true"');
    print('+ usesCleartextTraffic activé');
  }
  file.writeAsStringSync(xml);
  print('AndroidManifest.xml prêt.');
}
