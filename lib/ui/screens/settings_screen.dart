import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whisper/ui/screens/secrets.dart';

class SettingsScreen extends StatefulWidget {
  final String userEmail;
  const SettingsScreen({super.key, required this.userEmail});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  File? _imageFile;
  String? _imageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  String _userName = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadImage();
    getUserDetails();
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
                  title: Text('Settings'),
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
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_imageUrl != null)
                              ? NetworkImage(_imageUrl!)
                              : null,
                      backgroundColor: Colors.grey[300],
                      radius: 80,
                      child: _imageFile == null && _imageUrl == null
                          ? Icon(Icons.person, size: 80, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                GestureDetector(
                  onTap: () => _showNameChangeDialog(context),
                  child: Text(
                    _userName,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
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
                      widget.userEmail,
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
                    trailing: GestureDetector(
                      onTap: () => _showChangeStatusDialog(context),
                      child: Icon(
                        Icons.swap_horiz,
                        color: Colors.white,
                      ),
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

  Future<void> getUserDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userEmail)
        .get();
    if (doc.exists) {
      final userData = doc.data() as Map<String, dynamic>;
      setState(() {
        _userName = userData['displayName'];
        _status = userData['about'];
        // _imageUrl = userData['photoURL'];
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        // _imageUrl = pickedFile.path;
      });
      _uploadImage(File(pickedFile.path));
    }
  }

  Future<void> _loadImage() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userEmail)
        .get();
    if (doc.exists) {
      final userData = doc.data() as Map<String, dynamic>;
      setState(() {
        _imageUrl = userData['photoURL'];
      });
    }
    // }
  }

  Future<void> _uploadImage(File path) async {
    await uploadImageToImgBB(path);
    await saveUserProfileImage(widget.userEmail, _imageUrl!);
  }

  void _showNameChangeDialog(BuildContext context) {
    final nameController = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (builder) => AlertDialog(
        title: Text('Change Display Name'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
              labelText: 'New Name', hintText: 'Enter new cool display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                final newName = nameController.text.trim();
                _updateNameInFirebase(newName);
              },
              child: Text('Update'))
        ],
      ),
    );
  }

  Future<void> _updateNameInFirebase(String name) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userEmail)
          .update({'displayName': name});
      setState(() {
        _userName = name;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Display Name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error $e occured ')));
      }
    }
  }

  void _showChangeStatusDialog(BuildContext context) {
    final statusController = TextEditingController(text: _status);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Status'),
        content: TextField(
          controller: statusController,
          decoration: InputDecoration(
              labelText: 'New Status', hintText: 'Enter your new status'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final newStatus = statusController.text.trim();
              _updateStatusInFirebase(newStatus);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatusInFirebase(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userEmail)
          .update({'about': newStatus});
      setState(() {
        _status = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> uploadImageToImgBB(File imageFile) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse('https://api.imgbb.com/1/upload?key=$APIKEY'));
    request.files
        .add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        final Map<String, dynamic> data = jsonDecode(responseData.body);
        final imageUrl = data['data']['url']; // Get the image URL
        if (imageUrl != null) {
          setState(() {
            _imageUrl = imageUrl;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger(
        child: SnackBar(content: Text("Error uploading image: $e")),
      );
    }
  }

  Future<void> saveUserProfileImage(String email, String imageUrl) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'photoURL': imageUrl,
      }, SetOptions(merge: true));
      // print("Profile image URL saved successfully.");
    } catch (e) {
      ScaffoldMessenger(
        child: SnackBar(content: Text("Error saving profile image URL: $e")),
      );
    }
  }
}
