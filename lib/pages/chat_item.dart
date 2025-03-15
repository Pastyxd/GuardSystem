import 'package:flutter/material.dart';

class ChatItem extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final int unreadMessages;
  final String profilePicUrl;
  final VoidCallback onTap;

  const ChatItem({
    required this.name,
    required this.message,
    required this.time,
    required this.unreadMessages,
    required this.profilePicUrl,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    print("🔍 ChatItem build - name: $name, unreadMessages: $unreadMessages");
    return ListTile(
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: Colors.black,
            backgroundImage:
                profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
            child: profilePicUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          if (unreadMessages > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  unreadMessages > 9 ? "9+" : unreadMessages.toString(),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(time, style: const TextStyle(fontSize: 12)),
    );
  }
}
