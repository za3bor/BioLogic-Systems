import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:airwise/countryagrimap.dart';
import 'package:airwise/datainsights.dart';
import 'package:airwise/ecoscore.dart';
import 'package:airwise/plantsimulator.dart';
import 'package:airwise/weather.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class DashboardPage extends StatefulWidget {
  final String username;
  final String country;
  const DashboardPage({
    super.key,
    required this.username,
    required this.country,
  });
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String city = '';
  List<String> cities = [];
  int? aqi;
  List<Map<String, dynamic>> trend = [];
  Map<String, String> tips = {};
  double? temp, humidity, wind;
  String? weatherDesc;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCities(widget.country);
  }

  void fetchWeather(String cityName) async {
    final response = await http.get(
      Uri.parse('http://$ipAddress/weather?city=$cityName'),
    );
    if (response.statusCode == 200) {
      final w = jsonDecode(response.body);
      setState(() {
        temp = w['temp']?.toDouble();
        humidity = w['humidity']?.toDouble();
        wind = w['wind']?.toDouble();
        weatherDesc = w['desc'];
        isLoading = false;
      });
    }
  }

  void fetchCities(String country) async {
    setState(() => isLoading = true);
    final response = await http.get(
      Uri.parse('http://$ipAddress/cities?country=$country'),
    );
    if (response.statusCode == 200) {
      setState(() {
        cities = List<String>.from(jsonDecode(response.body)['cities']);
        city = cities.isNotEmpty ? cities[0] : '';
      });
      if (city.isNotEmpty) {
        fetchAQI(city);
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  void fetchAQI(String cityName) async {
    final response = await http.get(
      Uri.parse('http://$ipAddress/aqi?city=$cityName'),
    );
    if (response.statusCode == 200) {
      setState(() {
        aqi = jsonDecode(response.body)['aqi'];
        tips = getTips(aqi);
      });
      fetchTrend(cityName);
      fetchWeather(cityName);
    }
  }

  void fetchTrend(String cityName) async {
    final response = await http.get(
      Uri.parse('http://$ipAddress/aqi-trend?city=$cityName'),
    );
    if (response.statusCode == 200) {
      setState(() {
        trend = List<Map<String, dynamic>>.from(
          jsonDecode(response.body)['trend'],
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),

        title: Text(
          'AirWise Dashboard',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 6,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                gradient: LinearGradient(
                  colors: [Colors.green.shade900, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'AirWise Menu',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
            ...[
              ['Data Insights', DataInsightsPage(city: city)],
              ['Weather', WeatherPage(city: city)],
              ['EcoScore', EcoScorePage(username: widget.username)],
              ['Plant simulator', PlantSimulatorPage()],
              ['Country Agri Map', CountryAgriMapPage(country: widget.country)],
            ].map((item) {
              final title = item[0] as String;
              final page = item[1] as Widget;
              return ListTile(
                title: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                leading: Icon(_drawerIcon(title), color: Colors.green.shade700),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => page),
                  );
                },
                horizontalTitleGap: 10,
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
              );
            }),
          ],
        ),
      ),
      body:
          isLoading
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.green.shade700),
                    SizedBox(height: 16),
                    Text(
                      'Loading data...',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: () async => fetchAQI(city),
                color: Colors.green.shade700,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    Text(
                      'Good morning, ${widget.username}!',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.3),

                    const SizedBox(height: 16),

                    // Weather card with rounded corners and subtle shadow
                    if (temp != null && humidity != null && wind != null)
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      weatherDesc ?? "",
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '🌡️ ${temp!.toStringAsFixed(1)}°C\n💧 ${humidity!.toStringAsFixed(0)}%\n💨 ${wind!.toStringAsFixed(1)} m/s',
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        color: Colors.blueGrey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.wb_sunny,
                                size: 50,
                                color: Colors.orange.shade400,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2),

                    const SizedBox(height: 24),

                    // City dropdown with better styling
                    Row(
                      children: [
                        Text(
                          'City:',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: city,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.black,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items:
                                cities
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          style: GoogleFonts.nunito(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => city = v);
                                fetchAQI(v);
                              }
                            },
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.2),

                    const SizedBox(height: 32),

                    // AQI Card with bold text & icon
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: aqiColor(aqi),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        leading: Text(
                          aqiEmoji(aqi),
                          style: TextStyle(fontSize: 45),
                        ),
                        title: Text(
                          'AQI: ${aqi ?? "Loading..."}',
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          aqiStatus(aqi),
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 24),

                    // Tips Section Title
                    Text(
                      'Personalized Tips',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tips chips with uniform spacing and larger touch targets
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          tips.entries.map((e) {
                            return Chip(
                                  avatar: Icon(
                                    tipIcon(e.key),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  label: Text(
                                    e.value,
                                    style: GoogleFonts.nunito(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: tipColor(e.key),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 100.ms)
                                .scale(begin: Offset(0.9, 0.9));
                          }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // AQI Trend chart with header
                    Text(
                      'AQI Trend (Last 5 days)',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: trendChart(trend),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
    );
  }

  IconData _drawerIcon(String title) {
    switch (title) {
      case 'Pollution Growth Simulator':
        return Icons.show_chart_rounded;
      case 'Data Insights':
        return Icons.bar_chart;
      case 'Weather':
        return Icons.cloud;
      case 'Sports':
        return Icons.sports_soccer;
      case 'EcoScore':
        return Icons.eco;
      case 'Country Agri Map':
        return Icons.map;
      default:
        return Icons.menu;
    }
  }

  String aqiStatus(int? aqi) {
    switch (aqi) {
      case 1:
        return "Good 😊";
      case 2:
        return "Fair 🙂";
      case 3:
        return "Moderate 😐";
      case 4:
        return "Poor 😷";
      case 5:
        return "Very Poor 🤢";
      default:
        return "No data";
    }
  }

  String aqiEmoji(int? aqi) {
    switch (aqi) {
      case 1:
        return "😊";
      case 2:
        return "🙂";
      case 3:
        return "😐";
      case 4:
        return "😷";
      case 5:
        return "🤢";
      default:
        return "❓";
    }
  }

  Color aqiColor(int? aqi) {
    switch (aqi) {
      case 1:
        return Colors.green[200]!;
      case 2:
        return Colors.lightGreen[300]!;
      case 3:
        return Colors.yellow[300]!;
      case 4:
        return Colors.orange[300]!;
      case 5:
        return Colors.red[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  Map<String, String> getTips(int? aqi) {
    switch (aqi) {
      case 1:
        return {
          "health": "Enjoy your day outside!",
          "runners": "Perfect day for running.",
          "windows": "Open your windows freely.",
          "driving": "No restrictions.",
          "eco": "Plant trees or use eco transport.",
        };
      case 2:
        return {
          "health": "Sensitive groups take care.",
          "runners": "Safe for most, sensitive people reduce intensity.",
          "windows": "Open windows, but monitor air quality.",
          "driving": "Limit unnecessary driving.",
          "eco": "Use eco transport, avoid idling.",
        };
      case 3:
        return {
          "health": "Children/elderly limit outdoor activities.",
          "runners": "Consider indoor exercise.",
          "windows": "Limit window opening.",
          "driving": "Avoid peak hour driving.",
          "eco": "Carpool, avoid burning waste.",
        };
      case 4:
        return {
          "health": "Reduce outdoor activities.",
          "runners": "Not recommended to run outdoors.",
          "windows": "Keep windows closed.",
          "driving": "Avoid driving unless necessary.",
          "eco": "Support clean air initiatives.",
        };
      case 5:
        return {
          "health": "Stay indoors, avoid exertion.",
          "runners": "Do not run outdoors.",
          "windows": "Keep all windows closed.",
          "driving": "Do not drive unless necessary.",
          "eco": "Advocate for clean air policies.",
        };
      default:
        return {
          "health": "No data available.",
          "runners": "No data available.",
          "windows": "No data available.",
          "driving": "No data available.",
          "eco": "No data available.",
        };
    }
  }

  IconData tipIcon(String key) {
    switch (key) {
      case "health":
        return Icons.favorite;
      case "runners":
        return Icons.directions_run;
      case "windows":
        return Icons.window;
      case "driving":
        return Icons.directions_car;
      case "eco":
        return Icons.eco;
      default:
        return Icons.info;
    }
  }

  Color tipColor(String key) {
    switch (key) {
      case "health":
        return Colors.pinkAccent;
      case "runners":
        return Colors.blueAccent;
      case "windows":
        return Colors.teal;
      case "driving":
        return Colors.orangeAccent;
      case "eco":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget trendChart(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < trend.length; i++) {
      final aqi = trend[i]['aqi'] ?? 0;
      spots.add(FlSpot(i.toDouble(), aqi.toDouble()));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 5,
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine:
                (value) => FlLine(color: Colors.green.shade100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 20,
                getTitlesWidget:
                    (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
              ),
              axisNameWidget: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "AQI (Air Quality Index)",
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              axisNameSize: 30,
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 20,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  final date = trend[idx]['date'] as String;
                  final label = date.substring(5); // MM-DD
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
              axisNameWidget: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "Date",
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              axisNameSize: 28,
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.green.shade200, width: 1.5),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor:
                  (spot) => Colors.green.shade700.withValues(alpha: 0.8),
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final date = trend[spot.spotIndex]['date'].substring(0, 10);
                  final aqiValue = trend[spot.spotIndex]['aqi'].toString();
                  return LineTooltipItem(
                    '$date\nAQI: $aqiValue',
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.green.shade600,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isLast = index == spots.length - 1;
                  return FlDotCirclePainter(
                    radius: isLast ? 7 : 5,
                    color:
                        isLast ? Colors.green.shade900 : Colors.green.shade700,
                    strokeWidth: isLast ? 3 : 1,
                    strokeColor: isLast ? Colors.green.shade200 : Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade200.withValues(alpha: 0.9),
                    Colors.green.shade50.withValues(alpha: 0.7),
                    Colors.green.shade50.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
