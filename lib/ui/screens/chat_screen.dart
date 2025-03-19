import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:intl/intl.dart';
import 'package:whisper/ui/screens/individual_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? chatID;
  const ChatScreen({super.key, required this.chatID});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Stream<QuerySnapshot> _chatsStream;
  final String currentUserEmail =
      FirebaseAuth.instance.currentUser?.email ?? '';
  bool _isNavigating = false;
  bool _showDeleteButton = false;
  String _selectedChatId = '';

  @override
  void initState() {
    super.initState();
    // Set up the stream to fetch all chats where the current user is a participant
    _chatsStream = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserEmail)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();

    // Handle direct navigation to a specific chat
    if (widget.chatID != null && widget.chatID!.isNotEmpty) {
      // Using a post-frame callback to avoid build-during-build issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToChat(widget.chatID!);
      });
    }
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    // Get all unread messages for this chat where user is receiver
    final unreadMessages = await FirebaseFirestore.instance
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .where('receiver', isEqualTo: currentUserEmail)
        .where('isRead', isEqualTo: false)
        .get();

    // Create a batch update
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Commit the batch
    await batch.commit();
  }

  // Safer navigation method that prevents multiple navigations
  void _navigateToChat(String chatID, {String? recipientEmail}) {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });
    _markMessagesAsRead(chatID).then((_) {
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IndividualChatScreen(
            chatID: chatID,
            recipientEmail: recipientEmail,
          ),
        ),
      ).then((_) {
        // Reset flag when navigation completes
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      });
    });
  }

  // Get the other participant's email from the chat
  String getOtherParticipant(List<dynamic> participants) {
    return participants.firstWhere((email) => email != currentUserEmail,
        orElse: () => 'Unknown User');
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime messageDate =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final String timeFormat =
        DateFormat('h:mm a').format(dateTime); // 12-hour format with AM/PM

    // If message is from today, just show the time
    if (messageDate == today) {
      return timeFormat;
    }
    // If message is from yesterday, show "Yesterday" with time
    else if (messageDate == yesterday) {
      return 'Yesterday, $timeFormat';
    }
    // If message is within the last week (but not yesterday), show day name with time
    else if (now.difference(messageDate).inDays < 7) {
      return '${DateFormat('E').format(dateTime)} $timeFormat'; // EEEE gives full day name
    }
    // If message is older than a week, show date in DD/MM/YYYY format with time
    else {
      return '${DateFormat('dd/MM/yyyy').format(dateTime)}, $timeFormat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_showDeleteButton) {
          setState(() {
            _showDeleteButton = false;
            _selectedChatId = '';
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _chatsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // If there are no chats yet
            if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 80, color: Colors.grey),
                    const SizedBox(height: 20),
                    const Text(
                      'No conversations yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap the message button to start chatting',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            // Display the list of chats
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final chatDoc = snapshot.data!.docs[index];
                final chatData = chatDoc.data() as Map<String, dynamic>;

                final List<dynamic> participants =
                    chatData['participants'] ?? [];
                final String otherUserEmail = getOtherParticipant(participants);
                final String lastMessage =
                    chatData['lastMessage'] ?? 'Start a conversation...';
                final Timestamp? timestamp =
                    chatData['lastMessageTimestamp'] as Timestamp?;

                return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('messages')
                        .where('chatId', isEqualTo: chatDoc.id)
                        .where('receiver', isEqualTo: currentUserEmail)
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, unreadSnapshot) {
                      int unreadCount = 0;
                      if (unreadSnapshot.hasData) {
                        unreadCount = unreadSnapshot.data!.docs.length;
                      }
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUserEmail)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ListTile();
                          }
                          if (userSnapshot.hasError ||
                              !userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Text(
                                  '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text('Unknown User'),
                              subtitle: Text(lastMessage),
                            );
                          }
                          final userData =
                              userSnapshot.data!.data() as Map<String, dynamic>;
                          final String displayName =
                              userData['displayName'] ?? ' ';
                          final String imageUrl = userData['photoURL'];
                          return GestureDetector(
                            onLongPress: () {
                              setState(() {
                                _showDeleteButton = true;
                                _selectedChatId = chatDoc.id;
                              });
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade300,
                                backgroundImage: imageUrl.isNotEmpty
                                    ? NetworkImage(imageUrl)
                                    : null,
                                child: Text(
                                  otherUserEmail.isEmpty
                                      ? displayName[0].toUpperCase()
                                      : '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "   $lastMessage",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Show timestamp only if delete button is not shown for this chat
                                  if (_selectedChatId != chatDoc.id ||
                                      !_showDeleteButton)
                                    Text(formatTimestamp(timestamp)),
                                  const SizedBox(width: 8),
                                  // Show delete button if this chat is selected
                                  if (_selectedChatId == chatDoc.id &&
                                      _showDeleteButton)
                                    IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        _deleteChat(chatDoc.id);
                                        setState(() {
                                          _showDeleteButton = false;
                                          _selectedChatId = '';
                                        });
                                      },
                                    ),
                                  // Display unread badge only if there are unread messages
                                  if (unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => _navigateToChat(chatDoc.id,
                                  recipientEmail: otherUserEmail),
                            ),
                          );
                        },
                      );
                    });
              },
            );
          },
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
                colors: [Colors.purple, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: FloatingActionButton(
            onPressed: () {
              // Handle new chat creation
              _showNewChatDialog();
            },
            backgroundColor: Colors.transparent,
            child: const Icon(Icons.message),
          ),
        ),
      ),
    );
  }

  // Show dialog to start a new chat
  void _showNewChatDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  'Start a new chat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: 'Enter recipient email',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        final recipientEmail = emailController.text.trim();
                        if (recipientEmail.isEmpty) return;

                        if (recipientEmail == currentUserEmail) {
                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("You can't chat with yourself")),
                          );
                          Navigator.pop(context);
                          return;
                        }

                        // Create or find chat and navigate
                        _createOrFindChat(recipientEmail);
                        Navigator.pop(context);
                      },
                      child: Text('START'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      // Step 1: Get all messages in this chat
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .get();

      // Step 2: Create a batch to delete all messages
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Step 3: Delete the chat document itself
      batch.delete(FirebaseFirestore.instance.collection('chats').doc(chatId));

      // Step 4: Commit the batch operation
      await batch.commit();

      // Close the loading dialog
      // if (mounted) Navigator.of(context).pop();

      // // Show success message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Chat deleted successfully')),
      // );
    } catch (e) {
      // Close the loading dialog if there's an erro

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: $e')),
        );
      }
    }
  }

  // Create a new chat or find an existing one
  Future<void> _createOrFindChat(String recipientEmail) async {
    try {
      // Check if user exists
      final userExists = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .get()
          .then((snapshot) => snapshot.docs.isNotEmpty);

      if (!userExists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User doesn't exist")),
        );
        return;
      }

      // Check if chat already exists
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserEmail)
          .get();

      String? existingChatId;

      for (var doc in existingChatQuery.docs) {
        final List<dynamic> participants = doc['participants'] ?? [];
        if (participants.contains(recipientEmail)) {
          existingChatId = doc.id;
          break;
        }
      }

      if (existingChatId != null) {
        // Chat exists, navigate to it
        if (!mounted) return;
        _navigateToChat(existingChatId, recipientEmail: recipientEmail);
      } else {
        // Create new chat
        final newChatRef =
            await FirebaseFirestore.instance.collection('chats').add({
          'participants': [currentUserEmail, recipientEmail],
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        _navigateToChat(newChatRef.id, recipientEmail: recipientEmail);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
