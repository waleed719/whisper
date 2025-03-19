import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RecipientDetails extends StatefulWidget {
  final String email;
  const RecipientDetails({super.key, required this.email});

  @override
  State<RecipientDetails> createState() => _RecipientDetailsState();
}

class _RecipientDetailsState extends State<RecipientDetails> {
  String _userName = ' ';
  String _status = '';
  String _imageUrl = '';

  @override
  void initState() {
    super.initState();
    getUserDetails();
  }

  Future<void> getUserDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.email)
        .get();
    if (doc.exists) {
      final userData = doc.data() as Map<String, dynamic>;
      setState(() {
        _userName = userData['displayName'];
        _status = userData['about'];
        _imageUrl = userData['photoURL'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 20,
                ),
                AppBar(
                  backgroundColor: Colors.transparent,
                  title: Text('INFO'),
                  titleSpacing: 10,
                  titleTextStyle: TextStyle(
                    fontSize: 30,
                  ),
                ),
              ],
            )),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                // The CircleAvatar as the base
                CircleAvatar(
                  backgroundImage:
                      (_imageUrl.isNotEmpty) ? NetworkImage(_imageUrl) : null,
                  backgroundColor: Colors
                      .grey[300], // Fallback color when no image is available
                  radius: 80,
                  child:
                      Text(_imageUrl.isEmpty ? _userName[0].toUpperCase() : ''),
                ),

                const SizedBox(
                  height: 20,
                ),
                Text(
                  _userName,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                const SizedBox(
                  height: 20,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(8),
                    leading: Icon(
                      Icons.email_outlined,
                      color: Colors.white,
                    ),
                    title: Text(
                      widget.email,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(8),
                    leading: Icon(
                      Icons.flare,
                      color: Colors.white,
                    ),
                    title: Text(
                      _status,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
