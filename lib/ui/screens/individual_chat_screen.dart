import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whisper/ui/screens/recipient_details.dart';

class IndividualChatScreen extends StatefulWidget {
  final String chatID;
  final String? recipientEmail;

  const IndividualChatScreen({
    super.key,
    required this.chatID,
    this.recipientEmail,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<QuerySnapshot> _messagesStream;
  final String currentUserEmail =
      FirebaseAuth.instance.currentUser?.email ?? '';
  String _recipientEmail = '';
  bool _isLoading = true;
  String _recipientName = '';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.recipientEmail != null && widget.recipientEmail!.isNotEmpty) {
        _recipientEmail = widget.recipientEmail!;
      } else {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatID)
            .get();

        if (chatDoc.exists) {
          final chatData = chatDoc.data() as Map<String, dynamic>;
          final List<dynamic> participants = chatData['participants'] ?? [];
          _recipientName =
              participants.firstWhere((email) => email != currentUserEmail);
          _recipientEmail = participants.firstWhere(
            (email) => email != currentUserEmail,
            orElse: () => 'Unknown User',
          );
        }
      }
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_recipientEmail)
          .get();
      if (recipientDoc.exists) {
        final recipientData = recipientDoc.data();
        _recipientName = recipientData?['displayName'] ?? 'No Name';
      } else {
        _recipientName = 'No Name';
      }
      _messagesStream = FirebaseFirestore.instance
          .collection('messages')
          .where('chatId', isEqualTo: widget.chatID)
          .orderBy('createdAt', descending: false)
          .snapshots();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat: $e')),
        );
      }
    }
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _messageController.clear();

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'chatId': widget.chatID,
        'senderId': currentUserEmail,
        'reciever': _recipientEmail,
        'text': messageText,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': [],
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatID)
          .update({
        'lastMessage': messageText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserEmail,
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
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
      return '${DateFormat('E').format(dateTime)}, $timeFormat'; // EEEE gives full day name
    }
    // If message is older than a week, show date in DD/MM/YYYY format with time
    else {
      return '${DateFormat('dd/MM/yyyy').format(dateTime)}\n$timeFormat';
    }
  }

  void getUser() async {
    final DocumentSnapshot userdoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.recipientEmail)
        .get();
    final data = userdoc.data() as Map<String, dynamic>;
    final String name = data['displayName'] ?? ' ';
    setState(() {
      _recipientName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? null
            : GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (builder) =>
                              RecipientDetails(email: widget.recipientEmail!)));
                },
                child: Text(_recipientName)),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.data == null ||
                            snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child:
                                Text('No messages yet. Start a conversation!'),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            );
                          }
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final messageDoc = snapshot.data!.docs[index];
                            final messageData =
                                messageDoc.data() as Map<String, dynamic>;

                            final String senderId =
                                messageData['senderId'] ?? '';
                            final bool isMe = senderId == currentUserEmail;
                            final String text = messageData['text'] ?? '';
                            final Timestamp? timestamp =
                                messageData['createdAt'] as Timestamp?;

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isMe
                                      ? LinearGradient(
                                          colors: [Colors.purple, Colors.blue],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight)
                                      : LinearGradient(
                                          colors: [
                                            Color(0xFF800080),
                                            Color(0xFFFF1D84),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      text,
                                      style: isMe
                                          ? TextStyle(color: Colors.white)
                                          : TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(24)),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          onPressed: _sendMessage,
                          mini: true,
                          child: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
