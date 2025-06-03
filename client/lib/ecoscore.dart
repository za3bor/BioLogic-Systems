import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class EcoScorePage extends StatefulWidget {
  final String username;
  const EcoScorePage({super.key, required this.username});
  @override
  State<EcoScorePage> createState() => _EcoScorePageState();
}

class _EcoScorePageState extends State<EcoScorePage> {
  int score = 0;
  String challenge = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchScore();
    fetchChallenge();
  }

  void fetchScore() async {
    final response = await http.get(
      Uri.parse(
        'http://$ipAddress/eco-score?username=${Uri.encodeComponent(widget.username)}',
      ),
    );
    if (response.statusCode == 200) {
      setState(() => score = jsonDecode(response.body)['score']);
    }
  }

  void fetchChallenge() async {
    final response = await http.get(
      Uri.parse('http://$ipAddress/eco-challenge'),
    );
    if (response.statusCode == 200) {
      setState(() => challenge = jsonDecode(response.body)['challenge']);
    }
    setState(() => loading = false);
  }

  void logAction(String action) async {
    await http.post(
      Uri.parse('http://$ipAddress/eco-action'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': widget.username, 'action': action}),
    );
    fetchScore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🌱 My Eco Score',
          style: GoogleFonts.assistant(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body:
          loading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.green),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _InfoCard(
                      title: 'Your Eco Score',
                      content: '$score',
                      titleStyle: GoogleFonts.assistant(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      contentStyle: GoogleFonts.assistant(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                      backgroundColor: Colors.green[50]!,
                    ),
                    const SizedBox(height: 20),
                    _InfoCard(
                      title: '🌍 Weekly Challenge',
                      content: challenge,
                      titleStyle: GoogleFonts.assistant(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      contentStyle: GoogleFonts.assistant(
                        fontSize: 18,
                        color: Colors.blueGrey[700],
                      ),
                      backgroundColor: Colors.lightBlue[50]!,
                    ),
                    const SizedBox(height: 30),
                    _ActionButton(
                      icon: Icons.directions_bike,
                      label: 'I biked instead of driving!',
                      color: Colors.green[600]!,
                      onPressed: () => logAction('biked'),
                    ),
                    const SizedBox(height: 16),
                    _ActionButton(
                      icon: Icons.nature,
                      label: 'I planted a tree!',
                      color: Colors.green[900]!,
                      onPressed: () => logAction('planted_tree'),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final TextStyle titleStyle;
  final TextStyle contentStyle;
  final Color backgroundColor;

  const _InfoCard({
    required this.title,
    required this.content,
    required this.titleStyle,
    required this.contentStyle,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Text(title, style: titleStyle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(content, style: contentStyle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: GoogleFonts.assistant(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        shadowColor: Colors.black26,
      ),
      onPressed: onPressed,
    );
  }
}
