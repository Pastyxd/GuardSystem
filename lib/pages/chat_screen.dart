import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'UserProfileScreen.dart';
import 'package:guardsys/utils/encryption_helper.dart';

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

  /// 🔹 **Inicializace chatu (nastaví `chatId` pouze pro 2 uživatele)**
  Future<void> _setupChat() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (widget.isGroupChat) {
      chatId = widget.chatPartnerEmail; // Skupinový chat používá fixní ID
    } else {
      String currentUserId = currentUser.uid;
      String chatPartnerId = await _getChatPartnerId(widget.chatPartnerEmail);

      if (chatPartnerId.isEmpty) {
        print("⚠️ Chat partner ID nenalezeno!");
        setState(() => isLoading = false);
        return;
      }

      // Speciální případ pro chat sám se sebou
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
            ? await _getAllUserIds() // Přidání všech uživatelů do skupiny
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

  /// 🔹 **Získání `UID` chat partnera podle emailu**
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

  /// 🔹 **Odeslání zprávy (správně uloží do `chats/{chatId}/messages`)**
  void _sendMessage() async {
    if (_messageController.text.isNotEmpty && chatId != null) {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      String encryptedText =
          EncryptionHelper.encryptText(_messageController.text);

      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(currentUser.uid).get();
      String senderName = userDoc.exists
          ? userDoc["name"] ?? "Neznámý uživatel"
          : "Neznámý uživatel";

      DocumentReference chatRef = _firestore.collection("chats").doc(chatId);
      CollectionReference messagesRef = chatRef.collection("messages");

      // Získání ID příjemce
      String receiverId =
          chatId!.split("_").firstWhere((id) => id != currentUser.uid);

      await messagesRef.add({
        "text": encryptedText,
        "timestamp": FieldValue.serverTimestamp(),
        "sender": currentUser.uid,
        "senderName": senderName,
        "isRead": false,
      });

      // Aktualizace počtu nepřečtených zpráv pro příjemce
      await chatRef.update({
        "lastMessage": {
          "text": encryptedText,
          "timestamp": FieldValue.serverTimestamp(),
        },
        "unreadMessages.$receiverId": FieldValue.increment(1),
      });

      print("📨 Odeslána zpráva - chatId: $chatId, příjemce: $receiverId");

      _messageController.clear();
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return "Neznámý čas";

    final now = DateTime.now();
    final messageDate = timestamp.toDate();
    final difference = now.difference(messageDate);

    if (difference.inDays == 0) {
      // Dnes - zobrazit pouze čas
      return DateFormat('HH:mm').format(messageDate);
    } else if (difference.inDays == 1) {
      // Včera - zobrazit "Yesterday" + čas
      return "Yesterday ${DateFormat('HH:mm').format(messageDate)}";
    } else if (difference.inDays < 7) {
      // Tento týden - zobrazit zkratku dne + čas
      return "${DateFormat('E').format(messageDate)} ${DateFormat('HH:mm').format(messageDate)}";
    } else {
      // Starší než týden - zobrazit datum + čas
      return DateFormat('dd.MM.yyyy HH:mm').format(messageDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red[300],
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

                      // Aktualizace počtu nepřečtených zpráv
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
                                EncryptionHelper.decryptText(data["text"]);
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
                                          ? Colors.red[300]
                                          : Colors.red[100],
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
                        icon:
                            const Icon(Icons.send, color: Colors.red, size: 36),
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
