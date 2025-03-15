import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionHelper {
  // **AES 256-bitový klíč (32 znaků)**
  static final key =
      encrypt.Key.fromUtf8('12345678901234567890123456789012'); // 32 znaků
  static final iv = encrypt.IV.fromUtf8('1234567890123456'); // 16 znaků
  static final encrypter =
      encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

  /// 🔒 **Šifrování zprávy**
  static String encryptText(String plainText) {
    try {
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return encrypted.base64;
    } catch (e) {
      print("❌ Chyba při šifrování: $e");
      return "";
    }
  }

  /// 🔓 **Dešifrování zprávy**
  static String decryptText(String encryptedText) {
    try {
      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
      print("🔓 Dešifrovaná zpráva: $decrypted");
      return decrypted;
    } catch (e) {
      print("❌ Chyba při dešifrování: $e");
      return "🔒 Nelze dešifrovat";
    }
  }
}
