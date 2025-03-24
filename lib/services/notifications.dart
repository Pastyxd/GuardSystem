import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:guardsys/pages/chat_screen.dart';

// Globální klíč pro navigaci
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class Notifications {
  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static final Notifications _instance = Notifications._internal();
  factory Notifications() => _instance;
  Notifications._internal();

  Future<void> initialize() async {
    try {
      // pozadani o prav notifikaci
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // ziskani FCM tokenu
      String? token = await _messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }

// zjistovani o
      // zmenach tokenu
      _messaging.onTokenRefresh.listen(_saveFcmToken);

      // zprav v popredi
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // zprav na pozadi
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // kliknuti na notifikaci
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      print('✅ Notifikace inicializovány');
    } catch (e) {
      print('❌ Chyba při inicializaci notifikací: $e');
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        print('✅ FCM token uložen pro uživatele: ${user.uid}');
      }
    } catch (e) {
      print('❌ Chyba při ukládání FCM tokenu: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Přijata zpráva v popředí: ${message.notification?.title}');
    print('📝 Obsah zprávy: ${message.notification?.body}');
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📱 Přijata zpráva na pozadí: ${message.notification?.title}');
    print('📝 Obsah zprávy: ${message.notification?.body}');
  }

  // handler pro kliknuti na notifikaci
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('👆 Kliknutí na notifikaci: ${message.notification?.title}');

    //  ziskani dat z notofikace - od koho je
    final data = message.data;
    final senderName = data['senderName'] ?? "Neznámý uživatel";
    final senderEmail = data['senderEmail'];

    if (senderEmail == null) {
      print('❌ Chyba: Email odesílatele chybí v notifikaci');
      return;
    }

    // navigace na chat page
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatPartnerName: senderName,
            chatPartnerEmail: senderEmail,
          ),
        ),
      );
    } else {
      print('❌ Chyba: Context není dostupný pro navigaci');
    }
  }

  Future<void> sendNotification({
    required String recipientUid,
    required String senderName,
    required String message,
  }) async {
    try {
      final recipientDoc =
          await _firestore.collection('users').doc(recipientUid).get();
      final String? recipientToken = recipientDoc.data()?['fcmToken'];

      if (recipientToken != null) {
        print('📱 Odesílám notifikaci na token: $recipientToken');
        // logovani platnosti tokenu(pokud je null, tak se neodesila)
      } else {
        print('⚠️ Uživatel nemá nastavený FCM token');
      }
    } catch (e) {
      print('❌ Chyba při odesílání notifikace: $e');
    }
  }
}
