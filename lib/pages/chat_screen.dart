import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'UserProfileScreen.dart';
import 'package:guardsys/utils/encryption_service.dart';
import 'package:guardsys/services/notifications.dart';

class ChatScreen extends StatefulWidget {
  final String chatPartnerName;
  final String chatPartnerEmail;
  final bool isGroupChat;

  const ChatScreen({
    super.key,
    required this.chatPartnerName,
    required this.chatPartnerEmail,
    this.isGroupChat = false,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? chatId;
  bool isLoading = true;
  int unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _setupChat().then((_) => _markMessagesAsRead());
  }

  void _markMessagesAsRead() async {
    if (chatId == null) return;
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    print(
        "📖 Označuji zprávy jako přečtené - chatId: $chatId, uživatel: ${currentUser.uid}");

    await _firestore.collection("chats").doc(chatId).update({
      "unreadMessages.${currentUser.uid}": 0,
    });
    setState(() {
      unreadMessages = 0;
    });
  }

  /// inicializace chatu
  Future<void> _setupChat() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (widget.isGroupChat) {
      chatId = widget.chatPartnerEmail; // group chat s fixnim id
    } else {
      String currentUserId = currentUser.uid;
      String chatPartnerId = await _getChatPartnerId(widget.chatPartnerEmail);

      if (chatPartnerId.isEmpty) {
        print("⚠️ Chat partner ID nenalezeno!");
        setState(() => isLoading = false);
        return;
      }

      // self chat
      if (currentUserId == chatPartnerId) {
        chatId = "self_$currentUserId";
      } else {
        List<String> ids = [currentUserId, chatPartnerId]..sort();
        chatId = ids.join("_");
      }
    }

    DocumentSnapshot chatSnapshot =
        await _firestore.collection("chats").doc(chatId).get();

    if (!chatSnapshot.exists) {
      await _firestore.collection("chats").doc(chatId).set({
        "participants": widget.isGroupChat
            ? await _getAllUserIds() // pridani vsech uzivatelu do skupiny
            : [
                currentUser.uid,
                await _getChatPartnerId(widget.chatPartnerEmail)
              ],
        "createdAt": FieldValue.serverTimestamp(),
      });
      print("✅ Nový chat vytvořen: $chatId");
    } else {
      print("✅ Chat už existuje: $chatId");
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<List<String>> _getAllUserIds() async {
    QuerySnapshot querySnapshot = await _firestore.collection("users").get();
    return querySnapshot.docs.map((doc) => doc.id).toList();
  }

  /// ziskani UID chat partnera z mailu
  Future<String> _getChatPartnerId(String email) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection("users")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      } else {
        print("⚠️ Uživatelské ID pro email $email nenalezeno.");
        return "";
      }
    } catch (e) {
      print("❌ Chyba při získávání UID uživatele: $e");
      return "";
    }
  }

  /// 🔹 odeslani msg
  void _sendMessage() async {
    if (_messageController.text.isNotEmpty && chatId != null) {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      String messageText = _messageController.text;
      String encryptedText = EncryptionService.encryptText(messageText);

      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(currentUser.uid).get();
      String senderName = userDoc.exists
          ? userDoc["name"] ?? "Neznámý uživatel"
          : "Neznámý uživatel";

      print("🔄 Odesílání zprávy - Odesílatel: $senderName");

      DocumentReference chatRef = _firestore.collection("chats").doc(chatId);
      CollectionReference messagesRef = chatRef.collection("messages");

      // ziskani ID prijemce
      String receiverId =
          chatId!.split("_").firstWhere((id) => id != currentUser.uid);

      print("👤 ID příjemce: $receiverId");

      try {
        await messagesRef.add({
          "text": encryptedText,
          "timestamp": FieldValue.serverTimestamp(),
          "sender": currentUser.uid,
          "senderName": senderName,
          "senderEmail": currentUser.email,
          "isRead": false,
        });

        print("✅ Zpráva úspěšně uložena do Firestore");

        // aktualizace poctu unread zprav pro prijemce
        await chatRef.update({
          "lastMessage": {
            "text": encryptedText,
            "timestamp": FieldValue.serverTimestamp(),
          },
          "unreadMessages.$receiverId": FieldValue.increment(1),
        });

        print("✅ Počet nepřečtených zpráv aktualizován");

        // doesilani notifikace
        if (!widget.isGroupChat) {
          print("📱 Pokus o odeslání notifikace příjemci: $receiverId");
          try {
            final notifications = Notifications();
            await notifications.sendNotification(
              recipientUid: receiverId,
              senderName: senderName,
              message: messageText,
            );
            print("✅ Notifikace úspěšně odeslána");
          } catch (e) {
            print("❌ Chyba při odesílání notifikace: $e");
          }
        }

        _messageController.clear();
        print("✨ Proces odesílání zprávy dokončen");
      } catch (e) {
        print("❌ Chyba při odesílání zprávy: $e");
      }
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return "Neznámý čas";

    final now = DateTime.now();
    final messageDate = timestamp.toDate();
    final difference = now.difference(messageDate);

    // convert pro ceske dny
    final Map<String, String> czechDays = {
      'Mon': 'Po',
      'Tue': 'Út',
      'Wed': 'St',
      'Thu': 'Čt',
      'Fri': 'Pá',
      'Sat': 'So',
      'Sun': 'Ne',
    };

    // kontrola jestli je zprava dneska
    if (now.year == messageDate.year &&
        now.month == messageDate.month &&
        now.day == messageDate.day) {
      // Dnes - pouze čas
      return DateFormat('HH:mm').format(messageDate);
    }

    // kontrola jestli je zprava vcera
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == messageDate.year &&
        yesterday.month == messageDate.month &&
        yesterday.day == messageDate.day) {
      // Včera - "Yesterday" + čas
      return "Včera ${DateFormat('HH:mm').format(messageDate)}";
    }

    // kontrola casu zpravy
    if (difference.inDays < 7) {
      // tento tyden
      final englishDay = DateFormat('E').format(messageDate);
      final czechDay = czechDays[englishDay] ?? englishDay;
      return "$czechDay ${DateFormat('HH:mm').format(messageDate)}";
    }

    // starsi nez tyden
    return DateFormat('d.M.yyyy HH:mm').format(messageDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  name: widget.chatPartnerName,
                  email: widget.chatPartnerEmail,
                ),
              ),
            );
          },
          child: Column(
            children: [
              Text(
                widget.chatPartnerName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.chatPartnerEmail,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: true,
        actions: [
          if (unreadMessages > 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadMessages > 9 ? "9+" : unreadMessages.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: chatId == null
                        ? null
                        : _firestore
                            .collection("chats")
                            .doc(chatId)
                            .collection("messages")
                            .orderBy("timestamp", descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // aktualizace poctu unread zprav
                      if (chatId != null) {
                        _firestore
                            .collection("chats")
                            .doc(chatId)
                            .get()
                            .then((doc) {
                          if (doc.exists) {
                            int unread = doc.data()?["unreadMessages"]
                                    ?[_auth.currentUser?.uid] ??
                                0;
                            if (unread != unreadMessages) {
                              setState(() {
                                unreadMessages = unread;
                              });
                            }
                          }
                        });
                      }

                      return ListView(
                        reverse: true,
                        children: snapshot.data!.docs.map((doc) {
                          Map<String, dynamic> data =
                              doc.data() as Map<String, dynamic>;
                          bool isMe = _auth.currentUser?.uid == data["sender"];

                          String decryptedText = "";
                          try {
                            decryptedText =
                                EncryptionService.decryptText(data["text"]);
                          } catch (e) {
                            decryptedText = "🔒 Nelze dešifrovat";
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (!isMe &&
                                    _auth.currentUser?.email !=
                                        widget.chatPartnerEmail)
                                  FutureBuilder<DocumentSnapshot>(
                                    future: _firestore
                                        .collection("users")
                                        .doc(data["sender"])
                                        .get(),
                                    builder: (context, userSnapshot) {
                                      if (userSnapshot.hasData &&
                                          userSnapshot.data!.exists) {
                                        String profilePicUrl = userSnapshot
                                                .data!
                                                .get("profilePic") ??
                                            "";
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 4),
                                          child: CircleAvatar(
                                            radius: 25,
                                            backgroundImage: profilePicUrl
                                                    .isNotEmpty
                                                ? NetworkImage(profilePicUrl)
                                                : null,
                                            child: profilePicUrl.isEmpty
                                                ? const Icon(Icons.person,
                                                    size: 30)
                                                : null,
                                          ),
                                        );
                                      }
                                      return const SizedBox(width: 54);
                                    },
                                  ),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: EdgeInsets.only(
                                      left: isMe
                                          ? 50
                                          : (_auth.currentUser?.email ==
                                                  widget.chatPartnerEmail
                                              ? 50
                                              : 0),
                                      right: isMe ? 0 : 50,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .tertiary,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data["senderName"] ??
                                              "Neznámý uživatel",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          decryptedText,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatMessageTime(data["timestamp"]),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isMe) const SizedBox(width: 4),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onSubmitted: (value) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: "Napište zprávu...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.send,
                            color: Theme.of(context).colorScheme.primary,
                            size: 36),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
