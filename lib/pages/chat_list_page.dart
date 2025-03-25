import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'package:logger/logger.dart';
import 'chat_item.dart';
import 'group_chats_widget.dart';
import 'UserProfileScreen.dart';
import 'package:intl/intl.dart';
import 'package:guardsys/utils/encryption_service.dart';
import '../main.dart';

final logger = Logger();

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isRegistering = false;
  bool _isPasswordVisible = false;
  String? _passwordError;
  bool _isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      body: user == null ? _buildLoginForm() : _buildChatList(),
      floatingActionButton: user != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "profileButton",
                  onPressed: () async {
                    print('🔄 Otevírám profil uživatele...');
                    print('👤 Aktuální uživatel: ${user.email}');

                    final userDoc = await FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .get();

                    final userData = userDoc.data();
                    print('📄 Data uživatele: $userData');

                    if (userData != null) {
                      print('✅ Naviguji na profil uživatele');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            name: userData["name"] ?? "Neznámý uživatel",
                            email: userData["email"] ?? user.email!,
                          ),
                        ),
                      );
                    } else {
                      logger.e("Chyba: Data uživatele nenalezena.");
                    }
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "logoutButton",
                  onPressed: () async {
                    await _auth.signOut();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.exit_to_app, color: Colors.white),
                ),
              ],
            )
          : null,
    );
  }

  /// login a register form
  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRegistering ? "Registrace" : "Přihlášení",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isRegistering)
                      TextField(
                        controller: _nameController,
                        decoration: _inputDecoration("Jméno"),
                      ),
                    if (_isRegistering) const SizedBox(height: 10),

                    TextField(
                      controller: _emailController,
                      decoration: _inputDecoration("Email"),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),

                    if (_isRegistering)
                      TextField(
                        controller: _phoneController,
                        decoration: _inputDecoration("Telefonní číslo"),
                        keyboardType: TextInputType.phone,
                      ),
                    if (_isRegistering) const SizedBox(height: 10),

                    // pole pro heslo s passRevealem
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "Heslo",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        errorText: _passwordError,
                      ),
                      obscureText: !_isPasswordVisible,
                      onChanged: (value) {
                        setState(() {
                          if (value.length < 6) {
                            _passwordError = "Heslo musí mít alespoň 6 znaků.";
                          } else if (value.length > 20) {
                            _passwordError = "Heslo je příliš dlouhé.";
                          } else {
                            _passwordError = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        String email = _emailController.text.trim();
                        String password = _passwordController.text.trim(); // L
                        String name = _nameController.text.trim();
                        String phone = _phoneController.text.trim();

                        if (_isRegistering) {
                          await _registerUser(name, email, phone, password);
                        } else {
                          await _loginUser();
                        }
                      },
                      style: _buttonStyle(),
                      child: Text(
                          _isRegistering ? "Registrovat se" : "Přihlásit se"),
                    ),
                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isRegistering = !_isRegistering;
                        });
                      },
                      child: Text(
                        _isRegistering
                            ? "Už máte účet? Přihlásit se"
                            : "Nemáte účet? Zaregistrovat se",
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Container(
      color: const Color(0xFFF5F6F8),
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.tertiary,
            child: Column(
              children: [
                const SizedBox(
                  width: double.infinity,
                  child: GroupChatsWidget(),
                ),
                Divider(
                    height: 3,
                    thickness: 3,
                    color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection("users").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filtrovani aktualniho uzivatele pryc
                final filteredDocs = snapshot.data!.docs
                    .where((doc) =>
                        doc.id != FirebaseAuth.instance.currentUser!.uid)
                    .toList();

                return ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Color(0xFFE0E0E0),
                    thickness: 1,
                  ),
                  itemBuilder: (context, index) {
                    Map<String, dynamic> userData =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    String chatPartnerId = filteredDocs[index].id;
                    String currentUserId =
                        FirebaseAuth.instance.currentUser!.uid;

                    // vytvoreni chatId ze 2 uid
                    List<String> ids = [currentUserId, chatPartnerId]..sort();
                    String chatId = ids.join("_");

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("chats")
                          .doc(chatId)
                          .snapshots(),
                      builder: (context, chatSnapshot) {
                        if (!chatSnapshot.hasData ||
                            !chatSnapshot.data!.exists) {
                          return ChatItem(
                            name: userData['name'] ?? userData['email'],
                            message: "Žádné zprávy",
                            time: "",
                            unreadMessages: 0,
                            profilePicUrl: userData['profilePic'] ?? "",
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatPartnerName:
                                      userData['name'] ?? "Neznámý uživatel",
                                  chatPartnerEmail:
                                      userData['email'] ?? "Neznámý email",
                                ),
                              ),
                            ),
                          );
                        }

                        var chatData =
                            chatSnapshot.data!.data() as Map<String, dynamic>;

                        // desifrovani posledni zpravy
                        String lastMessageText = "Žádné zprávy";
                        if (chatData["lastMessage"]?["text"] != null) {
                          try {
                            lastMessageText = EncryptionService.decryptText(
                                chatData["lastMessage"]["text"]);
                          } catch (e) {
                            lastMessageText = "🔒 Nelze dešifrovat";
                          }
                        }

                        Timestamp? lastMessageTimestamp =
                            chatData["lastMessage"]?["timestamp"];
                        String formattedTime = lastMessageTimestamp != null
                            ? DateFormat('HH:mm')
                                .format(lastMessageTimestamp.toDate())
                            : "";

                        int unreadMessagesCount =
                            chatData["unreadMessages"]?[currentUserId] ?? 0;
                        print(
                            "📬 ChatListPage - unreadMessagesCount: $unreadMessagesCount pro uživatele: ${userData['name']}");

                        return ChatItem(
                          name: userData['name'] ?? userData['email'],
                          message: lastMessageText,
                          time: formattedTime,
                          unreadMessages: unreadMessagesCount,
                          profilePicUrl: userData['profilePic'] ?? "",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatPartnerName:
                                    userData['name'] ?? "Neznámý uživatel",
                                chatPartnerEmail:
                                    userData['email'] ?? "Neznámý email",
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerUser(
      String name, String email, String phone, String password) async {
    try {
      // Validace vstupních dat
      if (email.isEmpty || phone.isEmpty || password.isEmpty || name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Všechna pole musí být vyplněna')),
        );
        return;
      }

      // Validace emailu
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neplatný formát emailu')),
        );
        return;
      }

      // Validace hesla
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heslo musí mít alespoň 6 znaků')),
        );
        return;
      }

      // Validace telefonního čísla
      if (!RegExp(r'^\+?[0-9]{9,15}$')
          .hasMatch(phone.replaceAll(RegExp(r'[^0-9+]'), ''))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neplatný formát telefonního čísla')),
        );
        return;
      }

      // Nejprve vytvoříme uživatele v Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Nepodařilo se vytvořit uživatele');
      }

      // Poté uložíme data do Firestore
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid);

      final userData = {
        'email': email,
        'name': name,
        'phone': phone,
        'createdAt': DateTime.now().toIso8601String(),
        'lastActive': DateTime.now().toIso8601String(),
        'profilePic': '',
        'uid': userCredential.user!.uid,
      };

      await userDocRef.set(userData);
      print('✅ Data uložena do Firestore');

      print('✅ Registrace dokončena');

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {});
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainPage()),
        (route) => false,
      );
    } catch (e) {
      print('❌ Chyba při registraci: $e');
      String errorMessage = 'Chyba při registraci';

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'weak-password':
            errorMessage = 'Heslo je příliš slabé';
            break;
          case 'email-already-in-use':
            errorMessage = 'Email je již používán';
            break;
          case 'invalid-email':
            errorMessage = 'Neplatný email';
            break;
          default:
            errorMessage = e.message ?? 'Neznámá chyba';
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vyplňte email a heslo")),
      );
      return;
    }

    try {
      print("🔄 Pokus o přihlášení...");
      print("📧 Email: ${_emailController.text}");

      // Prihlaseni
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print("✅ Přihlášení úspěšné");
      print("👤 UID: ${userCredential.user?.uid}");

      // last activity
      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(userCredential.user!.uid)
            .update({
          "lastActive": FieldValue.serverTimestamp(),
        });
        print("✅ Aktualizován lastActive timestamp");
      }

      if (mounted) {
        setState(() {
          _isLoggedIn = true;
        });

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainPage()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase Auth chyba: ${e.code} - ${e.message}");
      String errorMessage = "Chyba při přihlášení";

      switch (e.code) {
        case 'user-not-found':
          errorMessage = "Uživatel nebyl nalezen";
          break;
        case 'wrong-password':
          errorMessage = "Nesprávné heslo";
          break;
        case 'invalid-email':
          errorMessage = "Neplatný email";
          break;
        case 'user-disabled':
          errorMessage = "Uživatel je deaktivován";
          break;
        default:
          errorMessage = e.message ?? "Neznámá chyba";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      print("❌ Chyba při přihlášení: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chyba při přihlášení")),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 2,
    );
  }
}
