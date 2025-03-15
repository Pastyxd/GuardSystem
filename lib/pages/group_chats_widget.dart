import 'package:flutter/material.dart';
import 'chat_screen.dart';

class GroupChatsWidget extends StatelessWidget {
  const GroupChatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // 🔥 **Full width přes celou obrazovku**
      padding: const EdgeInsets.symmetric(vertical: 8), // 📌 Zmenšená výška
      color: Colors.red.shade300,
      alignment: Alignment.center, // 📌 **Zarovnání obsahu**
      child: Column(
        mainAxisSize: MainAxisSize.min, // 📌 Zabrání nadměrnému roztahování
        children: [
          const Text(
            "Skupiny",
            style: TextStyle(
              fontSize: 20, // 🔹 Trochu menší text
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),

          /// 📌 **Kompaktní rozmístění pomocí Wrap**
          Wrap(
            spacing: 4, // 📌 **Menší mezery mezi obrázky**
            runSpacing: 4, // 📌 **Menší vertikální mezery**
            alignment: WrapAlignment.center,
            children: [
              _buildGroupButton(context, "Zelené", "group_zelene"),
              _buildGroupButton(context, "Panorama", "group_panorama"),
              _buildGroupButton(context, "Lázně", "group_lazne"),
              _buildGroupButton(context, "Všichni", "group_vsichni"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupButton(
      BuildContext context, String groupName, String groupId) {
    String imagePath = _getGroupImage(groupId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatPartnerName: groupName,
                  chatPartnerEmail: groupId,
                  isGroupChat: true,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(60), // 📌 Kulaté rohy
            child: Image.asset(
              imagePath,
              width: 100, // 📌 **Menší velikost obrázků pro úsporu místa**
              height: 100,
              fit: BoxFit.cover, // 📌 Automatické přizpůsobení obrázku
              errorBuilder: (context, error, stackTrace) => Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group, color: Colors.red, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          groupName,
          style: const TextStyle(color: Colors.black, fontSize: 14),
        ),
      ],
    );
  }

  /// 🔹 **Metoda pro výběr obrázku ke skupině**
  String _getGroupImage(String groupId) {
    switch (groupId) {
      case "group_zelene":
        return "assets/images/zelene.jpg";
      case "group_panorama":
        return "assets/images/panorama.jpg";
      case "group_lazne":
        return "assets/images/lazne.jpg";
      default:
        return ""; // 📌 Pokud není obrázek, použije výchozí ikonu
    }
  }
}
