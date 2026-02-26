import 'package:flutter/material.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _rememberMe = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E4560), // hsl(215,40%,30%)
              Color(0xFF70809C), // hsl(215,25%,55%)
              Color(0xFFA89587), // hsl(25,20%,60%)
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 60.0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                          decoration: const BoxDecoration(
                            color: Color(0xFF343D4B), // hsl(215,25%,27%)
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'BUSINESS SOLUTIONS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'AUTO BUSINESS SOLUTIONS',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Body
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabelWithLink('Username or Phone No.', 'Forgot username?'),
                              const SizedBox(height: 6),
                              const TextField(
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF2299CC)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildLabelWithLink('Password', 'Forgot password?'),
                              const SizedBox(height: 6),
                              const TextField(
                                obscureText: true,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF2299CC)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _rememberMe = !_rememberMe;
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: (val) {
                                              setState(() {
                                                _rememberMe = val!;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Remember me',
                                          style: TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const DashboardPage()),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.black45),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                    ),
                                    child: const Text(
                                      'Log In',
                                      style: TextStyle(color: Colors.black87, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildDivider(),
                              const SizedBox(height: 20),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 3.5,
                                children: [
                                  _buildSocialButton('Facebook', const Color(0xFF29487D), Icons.facebook),
                                  _buildSocialButton('Twitter', const Color(0xFF30A6D1), Icons.alternate_email),
                                  _buildSocialButton('Google +', const Color(0xFFD62D20), Icons.mail_outline),
                                  _buildSocialButton('Instagram', const Color(0xFF435064), Icons.camera_alt_outlined),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: TextButton(
                                  onPressed: () {},
                                  child: const Text(
                                    'Request for system user',
                                    style: TextStyle(color: Color(0xFF2299CC), fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Footer
                        Padding(
                          padding: const EdgeInsets.only(left: 32, right: 32, bottom: 28),
                          child: Column(
                            children: [
                              const Divider(height: 1, color: Colors.grey),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2299CC),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Create New Account',
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Powered by © Z-SOFTWARE',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelWithLink(String label, String linkText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        GestureDetector(
          onTap: () {},
          child: Text(
            linkText,
            style: const TextStyle(fontSize: 12, color: Color(0xFF2299CC)),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.grey)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              const Text('Login or ', style: TextStyle(fontSize: 13, color: Colors.black87)),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 13, color: Color(0xFF2299CC), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: Divider(color: Colors.grey)),
      ],
    );
  }

  Widget _buildSocialButton(String label, Color color, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
