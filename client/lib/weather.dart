import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class WeatherPage extends StatefulWidget {
  final String city;
  const WeatherPage({super.key, required this.city});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  double? temp, humidity, wind;
  String? desc;
  List<String> suggestions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  void fetchWeather() async {
    setState(() => loading = true);
    final response = await http.get(
      Uri.parse(
        'http://$ipAddress/weather?city=${Uri.encodeComponent(widget.city)}',
      ),
    );
    if (response.statusCode == 200) {
      final w = jsonDecode(response.body);
      setState(() {
        temp = w['temp']?.toDouble();
        humidity = w['humidity']?.toDouble();
        wind = w['wind']?.toDouble();
        desc = w['desc'];
        suggestions = List<String>.from(w['suggestions']);
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
                iconTheme: IconThemeData(color: Colors.white),

        title: Text(
          'Weather in ${widget.city}',
          style: GoogleFonts.assistant(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 2,
      ),
      backgroundColor: Colors.blue[50],
      body:
          loading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          desc?.toUpperCase() ?? '',
                          style: GoogleFonts.assistant(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[800],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _weatherInfo(
                              Icons.thermostat,
                              '${temp?.toStringAsFixed(1)}°C',
                              'Temperature',
                            ),
                            _weatherInfo(
                              Icons.water_drop,
                              '${humidity?.toStringAsFixed(0)}%',
                              'Humidity',
                            ),
                            _weatherInfo(
                              Icons.air,
                              '${wind?.toStringAsFixed(1)} m/s',
                              'Wind Speed',
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Suggestions:',
                            style: GoogleFonts.assistant(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: Colors.blueAccent[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...suggestions.map(
                          (s) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.tips_and_updates,
                              color: Colors.green[600],
                            ),
                            title: Text(
                              s,
                              style: GoogleFonts.assistant(fontSize: 16),
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

  Widget _weatherInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 36, color: Colors.blueAccent),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.assistant(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey[900],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.assistant(
            fontSize: 14,
            color: Colors.blueGrey[600],
          ),
        ),
      ],
    );
  }
}
