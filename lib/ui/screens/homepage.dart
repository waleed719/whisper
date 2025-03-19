import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:whisper/ui/authemtication/login.dart';
import 'package:whisper/ui/screens/chat_screen.dart';
import 'package:whisper/ui/screens/settings_screen.dart';

class Homepage extends StatefulWidget {
  final String currentUserEmail;

  const Homepage({super.key, required this.currentUserEmail});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Whisper'),
            titleTextStyle: const TextStyle(
                fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                ),
                onSelected: (value) {
                  if (value == 'Settings') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (builder) => SettingsScreen(
                                userEmail: widget.currentUserEmail)));
                  }
                  if (value == 'logout') {
                    askLogOutConfirmation(context);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'Settings',
                    child: Text('Settings'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: const ChatScreen(chatID: ''),
    );
  }

  void showStartChatDialog(BuildContext context, String currentUserEmail) {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Start a Chat"),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(hintText: "Enter email"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                String recipientEmail = emailController.text.trim();
                if (recipientEmail.isNotEmpty) {
                  Navigator.pop(dialogContext); // Close the dialog immediately
                  await checkUserAndStartChat(
                      context, currentUserEmail, recipientEmail);
                }
              },
              child: const Text("Start Chat"),
            ),
          ],
        );
      },
    );
  }

  Future<void> checkUserAndStartChat(
      BuildContext context, String userEmail, String recipientEmail) async {
    if (userEmail == recipientEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot chat with yourself!")),
      );
      return;
    }

    try {
      var userCollection = FirebaseFirestore.instance.collection("users");
      var recipientSnapshot =
          await userCollection.where("email", isEqualTo: recipientEmail).get();
      if (recipientSnapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User not found! Check the email.")),
          );
        }
        return;
      }

      String recipientId = recipientSnapshot.docs.first.id;
      String chatId = await startChat(userEmail, recipientEmail, recipientId);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(chatID: chatId)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  Future<String> startChat(
      String userEmail, String recipientEmail, String recipientId) async {
    String chatId = getChatId(userEmail, recipientEmail);
    DocumentReference chatRef =
        FirebaseFirestore.instance.collection("chats").doc(chatId);
    DocumentSnapshot chatSnapshot = await chatRef.get();

    if (!chatSnapshot.exists) {
      await chatRef.set({
        "chatId": chatId,
        "participants": [userEmail, recipientEmail],
        "lastMessage": "",
        "lastMessageTimestamp": FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }

  String getChatId(String userA, String userB) {
    return userA.hashCode <= userB.hashCode
        ? "${userA}_$userB"
        : "${userB}_$userA";
  }

  Future<void> askLogOutConfirmation(BuildContext context) {
    String text =
        count == 0 ? 'Are you going to leave me 😢' : 'Please don\'t go 😢';

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 5,
          insetPadding: EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).dialogBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: GradientBoxBorder(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                width: 5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'CANCEL',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (count >= 1) {
                            await FirebaseAuth.instance.signOut();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (builder) => LoginScreen()),
                              (route) => false,
                            );
                          } else {
                            setState(() {
                              count++;
                              Navigator.pop(context);
                              askLogOutConfirmation(context);
                            });
                          }
                        },
                        child: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
