import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  /// nacteni uzivatelskych dat
  void _fetchUserData() async {
    try {
      // Najít uživatele podle emailu
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

          print("🔄 Načtena data uživatele: ${widget.email}");
          print("📱 Telefon: $phoneNumber");
          print("🖼️ Profilová fotka: $profilePicUrl");

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
          SettableMetadata(contentType: 'image/jpeg'), // Nastavení metadata
        );
      } else {
        File file = File(pickedFile.path);
        uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'), // Nastavení metadata
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

  /// 📌 **Zkopíruje telefonní číslo do schránky**
  void _copyPhoneNumber() {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Telefonní číslo zkopírováno!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[300],
      appBar: AppBar(
        title: const Text("Profil uživatele"),
        backgroundColor: Colors.red[400],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () async {
                print("📸 Uživatel klikl na profilovku");
                print("📧 Email profilu: ${widget.email}");
                print("👤 Aktuální uživatel: ${_auth.currentUser?.email}");
                print(
                    "🔍 Porovnání: ${widget.email == _auth.currentUser?.email}");

                if (widget.email == _auth.currentUser?.email) {
                  print("✅ Je to vlastní profil, spouštím nahrávání fotky");
                  await _pickAndUploadImage();
                } else {
                  print("❌ Není to vlastní profil, nahrávání fotky zakázáno");
                }
              },
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[700],
                backgroundImage: profilePicUrl.isNotEmpty
                    ? NetworkImage(profilePicUrl)
                    : null,
                child: (profilePicUrl.isEmpty)
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.name,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text(
              widget.email,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.black54, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phoneNumber,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.copy, color: Colors.black54, size: 20),
                    onPressed: _copyPhoneNumber,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
