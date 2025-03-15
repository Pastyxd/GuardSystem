import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_list_page.dart';
// import 'dart:developer';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscurePassword = true; // 👁 Stav pro skrytí/zobrazení hesla
  String? _errorMessage;
  String? _passwordValidationMessage;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => _passwordValidationMessage = null);
    } else if (password.length < 6) {
      setState(() => _passwordValidationMessage = "Heslo je příliš krátké.");
    } else if (password.length > 20) {
      setState(() => _passwordValidationMessage = "Heslo je příliš dlouhé.");
    } else {
      setState(() => _passwordValidationMessage = "✔ Heslo je v pořádku.");
    }
  }

  Future<void> _loginUser(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatListPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = "Uživatel nenalezen.";
        } else if (e.code == 'wrong-password') {
          _errorMessage = "Nesprávné heslo.";
        } else if (e.code == 'invalid-email') {
          _errorMessage = "Neplatný email.";
        } else {
          _errorMessage = "Chyba při přihlášení: ${e.message}";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF03C39),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width * 0.7,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Přihlášení",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: _validatePassword,
                  decoration: InputDecoration(
                    labelText: "Heslo",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: _togglePasswordVisibility,
                    ),
                  ),
                ),
                if (_passwordValidationMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _passwordValidationMessage!,
                      style: TextStyle(
                        color: _passwordValidationMessage!.contains("✔")
                            ? Colors.green
                            : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () => _loginUser(
                      _emailController.text, _passwordController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Přihlásit se"),
                ),
                const SizedBox(height: 10),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChatListPage()),
                    );
                  },
                  child: const Text("Nemáte účet? Zaregistrovat se"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
