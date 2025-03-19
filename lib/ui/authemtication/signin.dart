import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whisper/ui/authemtication/login.dart';
import 'package:whisper/widgets/custom_text_field.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _register() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      await userCredential.user?.sendEmailVerification();

      if (mounted) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(_emailController.text.trim())
            .set({
          'uid': FirebaseAuth.instance.currentUser?.uid,
          'email': _emailController.text.trim(),
          'displayName': _nameController.text.trim(),
          'photoURL': '',
          'about': 'Hey there! I am using Whisper.',
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
        });

        _showSnackBar(
            'Account created! Please check your email to verify your account.',
            Colors.green);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (builder) => const LoginScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered. Try logging in.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak. Choose a stronger one.';
      } else {
        errorMessage = 'An error occurred: ${e.message}';
      }

      if (mounted) {
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An unexpected error occurred', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: [Colors.purple, Colors.blue])
                  .createShader(bounds),
          child: const Text(
            'Register',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    LinearGradient(colors: [Colors.purple, Colors.blue])
                        .createShader(bounds),
                child: const Text(
                  'Welcome to Whisper',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              CustomTextField(controller: _nameController, hintText: 'Name'),
              const SizedBox(
                height: 20,
              ),
              CustomTextField(controller: _emailController, hintText: 'Email'),
              const SizedBox(
                height: 20,
              ),
              CustomTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  isPassword: true),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient:
                      LinearGradient(colors: [Colors.purple, Colors.blue]),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create New Account',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (builder) => LoginScreen()));
                  },
                  child: Text('Already have an account? Login'))
            ],
          ),
        ),
      ),
    );
  }
}
