import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class UserProfileScreen extends StatefulWidget {
  final String name;
  final String email;

  const UserProfileScreen({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String phoneNumber = "Není k dispozici";
  String profilePicUrl = "";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isPickingImage = false;
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _notificationsEnabled = true;
  File? _imageFile;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    print("🚀 Inicializace UserProfileScreen");
    print("📧 Email profilu: ${widget.email}");
    _checkIfOwnProfile();
    _fetchUserData();
  }

  /// kontrola, zda je zobrazený profil vlastní
  void _checkIfOwnProfile() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      print("🔍 Kontrola vlastního profilu:");
      print("📧 Aktuální uživatel: ${currentUser.email}");
      print("📧 Zobrazený profil: ${widget.email}");
      print("🔍 Porovnání: ${currentUser.email == widget.email}");
      print("🔍 Typ aktuálního emailu: ${currentUser.email.runtimeType}");
      print("🔍 Typ widget.email: ${widget.email.runtimeType}");
      print("🔍 Délka aktuálního emailu: ${currentUser.email?.length}");
      print("🔍 Délka widget.email: ${widget.email.length}");

      setState(() {
        _isOwnProfile = currentUser.email == widget.email;
      });
    } else {
      print("⚠️ Žádný přihlášený uživatel!");
    }
  }

  /// nacteni uzivatelskych dat
  void _fetchUserData() async {
    try {
      // najit uzivatele podle mailu
      final QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: widget.email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty && mounted) {
        final userData = userQuery.docs.first.data() as Map<String, dynamic>;
        setState(() {
          phoneNumber = userData["phone"] ?? "Není k dispozici";
          profilePicUrl = userData["profilePic"] ?? "";
          _notificationsEnabled = userData["notificationsEnabled"] ?? true;

          print("🔄 Načtena data uživatele: ${widget.email}");
          print("📱 Telefon: $phoneNumber");
          print("🖼️ Profilová fotka: $profilePicUrl");
          print(
              "🔔 Notifikace: ${_notificationsEnabled ? "Zapnuty" : "Vypnuty"}");

          if (profilePicUrl.isEmpty) {
            print("⚠️ Uživatel nemá nastavenou profilovou fotku.");
          }
        });
      }
    } catch (e) {
      print("❌ Chyba při načítání dat uživatele: $e");
    }
  }

  /// vyber a nahrani fotky do firebase
  Future<void> _pickAndUploadImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        print("⚠️ Uživatel nevybral žádný obrázek.");
        return;
      }

      final userId = _auth.currentUser!.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images/$userId/profile.jpg');

      print(
          "📤 PŘIPRAVUJI NAHRÁNÍ OBRÁZKU DO: profile_images/$userId/profile.jpg");

      UploadTask uploadTask;
      if (kIsWeb) {
        Uint8List bytes = await pickedFile.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        File file = File(pickedFile.path);
        uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      TaskSnapshot snapshot = await uploadTask;
      if (snapshot.state == TaskState.success) {
        final url = await snapshot.ref.getDownloadURL();
        print("✅ Obrázek úspěšně nahrán. URL: $url");

        final urlWithTimestamp =
            "$url?t=${DateTime.now().millisecondsSinceEpoch}";

        await FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .update({
          "profilePic": urlWithTimestamp,
        });

        print("✅ URL profilové fotky uložena do Firestore: $urlWithTimestamp");

        if (mounted) {
          setState(() {
            profilePicUrl = urlWithTimestamp;
          });
        }
      } else {
        print("❌ Chyba: Obrázek nebyl úspěšně nahrán!");
      }
    } catch (e) {
      print("❌ Chyba při nahrávání obrázku: $e");
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  /// 📞 **Zavolá na telefonní číslo**
  Future<void> _callPhoneNumber() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final isEmulator = androidInfo.isPhysicalDevice == false;

    if (isEmulator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Volání není dostupné na emulátoru. Použijte reálné zařízení."),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nelze zavolat na toto číslo")),
      );
    }
  }

  void _copyPhoneNumber() {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Telefonní číslo zkopírováno!")),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    _oldPasswordController.clear();
    _newPasswordController.clear();
    setState(() {
      _showOldPassword = false;
      _showNewPassword = false;
    });

    print("📱 Otevírám dialog pro změnu hesla");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 20,
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Změna hesla',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _oldPasswordController,
                              obscureText: !_showOldPassword,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Staré heslo',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showOldPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showOldPassword = !_showOldPassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _newPasswordController,
                              obscureText: !_showNewPassword,
                              decoration: InputDecoration(
                                labelText: 'Nové heslo',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showNewPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showNewPassword = !_showNewPassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Zrušit'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _changePassword(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Změnit heslo'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    print("🔍 Dialog pro změnu hesla otevřen");
  }

  Future<void> _changePassword() async {
    try {
      // overeni se starym heslem
      final user = _auth.currentUser;
      final credential = EmailAuthProvider.credential(
        email: user?.email ?? '',
        password: _oldPasswordController.text,
      );

      await user?.reauthenticateWithCredential(credential);

      // zmena hesla
      await user?.updatePassword(_newPasswordController.text);

      if (mounted) {
        Navigator.pop(context); // Zavře dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heslo bylo úspěšně změněno')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba: Nesprávné staré heslo')),
        );
      }
    }
  }

  Future<void> _showChangePhoneDialog() async {
    _phoneController.text = phoneNumber;

    print("📱 Otevírám dialog pro změnu telefonního čísla");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Změna telefonního čísla'),
          content: TextField(
            controller: _phoneController,
            autofocus: true,
            maxLength: 17,
            decoration: const InputDecoration(
              labelText: 'Nové telefonní číslo',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            keyboardType: TextInputType.phone,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () => _changePhoneNumber(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Změnit číslo'),
            ),
          ],
        );
      },
    );
    print("🔍 Dialog pro změnu telefonního čísla otevřen");
  }

  Future<void> _changePhoneNumber() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'phone': _phoneController.text});

        setState(() {
          phoneNumber = _phoneController.text;
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Telefonní číslo bylo úspěšně změněno')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba při změně telefonního čísla')),
        );
      }
    }
  }

  /// prepinani notifikaci
  void _toggleNotifications(bool value) async {
    try {
      final userId = _auth.currentUser!.uid;
      await FirebaseFirestore.instance.collection("users").doc(userId).update({
        "notificationsEnabled": value,
      });
      setState(() {
        _notificationsEnabled = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? "Notifikace zapnuty" : "Notifikace vypnuty"),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      print("❌ Chyba při změně nastavení notifikací: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Chyba při změně nastavení notifikací"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomPadding > 0;

    print("🏗️ Build UserProfileScreen:");
    print("🔍 _isOwnProfile: $_isOwnProfile");
    print("⌨️ isKeyboardOpen: $isKeyboardOpen");

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.person, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Profil uživatele",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isOwnProfile ? _pickAndUploadImage : null,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  Theme.of(context).colorScheme.tertiary,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (profilePicUrl.isNotEmpty
                                      ? NetworkImage(profilePicUrl)
                                          as ImageProvider
                                      : null),
                              child:
                                  _imageFile == null && (profilePicUrl.isEmpty)
                                      ? const Icon(Icons.person,
                                          size: 60, color: Colors.white)
                                      : null,
                            ),
                          ),
                          if (_isOwnProfile)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _callPhoneNumber,
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.black),
                            const SizedBox(width: 12),
                            Text(
                              phoneNumber,
                              style: const TextStyle(
                                  color: Colors.black, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.black),
                      onPressed: _copyPhoneNumber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Divider(
                color: Colors.white,
                thickness: 1,
                height: 32,
              ),
              if (!isKeyboardOpen &&
                  widget.email.toLowerCase() ==
                      _auth.currentUser?.email?.toLowerCase()) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings, color: Colors.white, size: 24),
                    SizedBox(width: 4),
                    Text(
                      "Nastavení",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // prepinac notifikaci
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined,
                        color: Colors.black),
                    title: const Text("Notifikace",
                        style: TextStyle(color: Colors.black)),
                    subtitle: Text(
                        _notificationsEnabled ? "Zapnuto" : "Vypnuto",
                        style: const TextStyle(color: Colors.black)),
                    trailing: SizedBox(
                      width: 80,
                      child: Switch(
                        value: _notificationsEnabled,
                        onChanged: (bool value) {
                          _toggleNotifications(value);
                        },
                        activeColor: Colors.blue,
                      ),
                    ),
                  ),
                ),
                // zmena telefonniho cisla
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.phone, color: Colors.black),
                    title: const Text("Změnit telefonní číslo",
                        style: TextStyle(color: Colors.black)),
                    subtitle: Text(phoneNumber,
                        style: const TextStyle(color: Colors.black)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.black),
                    onTap: () {
                      _showChangePhoneDialog();
                    },
                  ),
                ),
                // zmena hesla
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading:
                        const Icon(Icons.lock_outline, color: Colors.black),
                    title: const Text("Změnit heslo",
                        style: TextStyle(color: Colors.black)),
                    subtitle: const Text("Klikněte pro změnu",
                        style: TextStyle(color: Colors.black)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.black),
                    onTap: () {
                      _showChangePasswordDialog();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/',
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        print("❌ Chyba při odhlašování: $e");
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Chyba při odhlašování"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Odhlásit se',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
