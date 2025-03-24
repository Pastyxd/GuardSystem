import 'package:flutter/material.dart';
import 'chat_screen.dart';

class GroupChatsWidget extends StatelessWidget {
  const GroupChatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // full widh bar
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: const Color(0xFF1565C0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Skupiny",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
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
            borderRadius: BorderRadius.circular(60),
            child: Image.asset(
              imagePath,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.group, color: Color(0xFF0096C7), size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          groupName,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// obrazky skupin
  String _getGroupImage(String groupId) {
    switch (groupId) {
      case "group_zelene":
        return "assets/images/zelene.jpg";
      case "group_panorama":
        return "assets/images/panorama.jpg";
      case "group_lazne":
        return "assets/images/lazne.jpg";
      default:
        return "";
    }
  }
}
