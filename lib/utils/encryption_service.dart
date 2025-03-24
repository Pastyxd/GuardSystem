import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class EncryptionService {
  // gettery pro klice
  static String get _rawKey => dotenv.env['ENCRYPTION_KEY'] ?? '';
  static String get _rawIv => dotenv.env['ENCRYPTION_IV'] ?? '';

  // jeho generovani
  static encrypt.Key _getKey() {
    if (_rawKey.isEmpty) {
      throw Exception('Šifrovací klíč není nastaven');
    }

    final keyBytes =
        Uint8List.fromList(sha256.convert(utf8.encode(_rawKey)).bytes);

    return encrypt.Key(keyBytes);
  }

  // Generování vektoru
  static encrypt.IV _getIV() {
    if (_rawIv.isEmpty) {
      throw Exception('Inicializační vektor není nastaven');
    }

    final rawBytes = utf8.encode(_rawIv);

    // 16bytu
    if (rawBytes.length > 16) {
      return encrypt.IV(Uint8List.fromList(rawBytes.sublist(0, 16)));
    } else {
      final paddedBytes = List<int>.filled(16, 0);
      for (var i = 0; i < rawBytes.length; i++) {
        paddedBytes[i] = rawBytes[i];
      }
      return encrypt.IV(Uint8List.fromList(paddedBytes));
    }
  }

  // sifrovani textu
  static String encryptText(String text) {
    try {
      final key = _getKey();
      final iv = _getIV();
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final encrypted = encrypter.encrypt(text, iv: iv);
      return encrypted.base64;
    } catch (e) {
      return text;
    }
  }

  // desifrovani
  static String decryptText(String encryptedText) {
    try {
      final key = _getKey();
      final iv = _getIV();
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
      return decrypted;
    } catch (e) {
      return '🔒 Nelze dešifrovat';
    }
  }
}
