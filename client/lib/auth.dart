import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:airwise/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  String username = '';
  String password = '';
  String country = '';
  String city = '';
  String message = '';
  List<String> countries = [];
  List<String> cities = [];
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    fetchCountries();
  }

  void fetchCountries() async {
    final response = await http.get(Uri.parse('https://$ipAddress/api/countries'));

    if (response.statusCode == 200) {
      setState(() {
        countries = List<String>.from(jsonDecode(response.body)['countries']);
        country = countries.isNotEmpty ? countries[0] : '';
      });
      if (country.isNotEmpty) fetchCities(country);
    }
  }

  void fetchCities(String country) async {
    final response = await http.get(
      Uri.parse('https://$ipAddress/api/cities?country=$country'),
    );
    if (response.statusCode == 200) {
      setState(() {
        cities = List<String>.from(jsonDecode(response.body)['cities']);
        city = cities.isNotEmpty ? cities[0] : '';
      });
    }
  }

  void register() async {
    final response = await http.post(
      Uri.parse('https://$ipAddress/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'country': country,
      }),
    );
    if (response.statusCode == 200) {
      setState(() => message = 'Registration successful! Please login.');
      setState(() => isLogin = true);
    } else {
      setState(
        () =>
            message =
                jsonDecode(response.body)['message'] ?? 'Registration failed',
      );
    }
  }

  void login() async {
    final response = await http.post(
      Uri.parse('https://$ipAddress/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final userCountry = jsonDecode(response.body)['country'];
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    DashboardPage(username: username, country: userCountry),
          ),
        );
      }
    } else {
      setState(
        () => message = jsonDecode(response.body)['message'] ?? 'Login failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco,
                    color: Colors.green[600],
                    size: 64,
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2),
                  const SizedBox(height: 12),
                  Text(
                    isLogin ? 'Login' : 'Register',
                    style: GoogleFonts.assistant(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2, delay: 100.ms),
                  const SizedBox(height: 24),
                  TextField(
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2.0),
                      ),
                      labelText: 'Username',
                      labelStyle: TextStyle(
                        color: Colors.black,
                      ), // Unfocused label

                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (v) => username = v,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 16),
                  TextField(
                        decoration: InputDecoration(
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.black,
                              width: 2.0,
                            ),
                          ),
                          labelStyle: TextStyle(color: Colors.black), //
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        onChanged: (v) => password = v,
                      )
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.2, curve: Curves.easeOut),

                  if (!isLogin) ...[
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: country,
                            isExpanded: true, // ✅ Important to avoid overflow
                            decoration: const InputDecoration(
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.black,
                                  width: 2.0,
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.black), //
                              labelText: 'Country',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                countries
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis, // ✅ Prevent long text overflow
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => country = v);
                                fetchCities(v);
                              }
                            },
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isLogin ? login : register,
                    child: Text(
                      isLogin ? 'Login' : 'Register',
                      style: GoogleFonts.assistant(fontSize: 18,color: Colors.white),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin
                          ? 'No account? Register'
                          : 'Have an account? Login',
                      style: GoogleFonts.assistant(
                        color: Colors.green[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 12),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: GoogleFonts.assistant(color: Colors.red),
                    ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1),
        ),
      ),
    );
  }
}
