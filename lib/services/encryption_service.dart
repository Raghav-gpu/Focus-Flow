// lib/services/encryption_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  final _secureStorage = const FlutterSecureStorage();
  final String _keyStorageKey = 'encryption_key';

  Future<String> _getOrCreateKey() async {
    String? key = await _secureStorage.read(key: _keyStorageKey);
    if (key == null) {
      key = base64Url
          .encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
      await _secureStorage.write(key: _keyStorageKey, value: key);
    }
    return key;
  }

  Future<String> encrypt(String plainText) async {
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(Key.fromBase64(key), mode: AESMode.cbc));
    final iv = IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  Future<String> decrypt(String encryptedText) async {
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(Key.fromBase64(key), mode: AESMode.cbc));
    final parts = encryptedText.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted format');
    final iv = IV.fromBase64(parts[0]);
    final encryptedBody = parts[1];
    return encrypter.decrypt(Encrypted.fromBase64(encryptedBody), iv: iv);
  }
}
