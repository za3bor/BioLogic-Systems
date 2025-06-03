import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

const String serverUrl =
    'http://$ipAddress'; // Change to your server's IP if needed

class PlantSimulatorPage extends StatefulWidget {
  const PlantSimulatorPage({super.key});

  @override
  State<PlantSimulatorPage> createState() => _PlantSimulatorPageState();
}

class _PlantSimulatorPageState extends State<PlantSimulatorPage> {
  double temp = 22;
  double humidity = 60;
  double aqi = 1;
  String plant = "Wheat";
  List<double> growth = [];
  String result = "";
  List<String> reasons = [];
  bool loading = false;
  double? thriving;
  Map<String, List<num>>? ideal;

  void simulate() async {
    setState(() {
      loading = true;
      growth = [];
      result = "";
      reasons = [];
      thriving = null; // reset thriving on new simulate
    });

    final response = await http.post(
      Uri.parse('$serverUrl/simulate-plant'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'plant': plant,
        'temp': temp,
        'humidity': humidity,
        'aqi': aqi.round(),
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        growth =
            List<Map<String, dynamic>>.from(
              data['growthSeries'],
            ).map((e) => (e['N'] as num).toDouble()).toList();
        result = data['result'];
        reasons = List<String>.from(data['reasons']);
        thriving = (data['thriving'] as num).toDouble(); // get thriving value
        ideal = Map<String, List<num>>.from(
          (data['ideal'] as Map).map(
            (key, value) => MapEntry(key.toString(), List<num>.from(value)),
          ),
        );

        loading = false;
      });
    } else {
      setState(() {
        result = "Simulation failed.";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.green.shade600;
    return Scaffold(
      appBar: AppBar(
        title: Text("Plant Growth Simulator", style: GoogleFonts.assistant()),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: plant,
                      decoration: InputDecoration(
                        labelText: 'Select Plant',
                        labelStyle: GoogleFonts.assistant(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items:
                          [
                                "Wheat",
                                "Tomato",
                                "Sunflower",
                                "Corn",
                                "Potato",
                                "Rice",
                                "Cucumber",
                                "Pepper",
                                "Lettuce",
                                "Carrot",
                                "Eggplant",
                              ]
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p,
                                    style: GoogleFonts.assistant(),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => plant = v!),
                    ),
                    const SizedBox(height: 20),
                    buildSlider(
                      label: "Temperature",
                      value: temp,
                      min: 0,
                      max: 40,
                      unit: "°C",
                      onChanged: (v) => setState(() => temp = v),
                    ),
                    const SizedBox(height: 10),
                    buildSlider(
                      label: "Humidity",
                      value: humidity,
                      min: 0,
                      max: 100,
                      unit: "%",
                      onChanged: (v) => setState(() => humidity = v),
                    ),
                    const SizedBox(height: 10),
                    buildSlider(
                      label: "Air Quality Index",
                      value: aqi,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      unit: "",
                      onChanged: (v) => setState(() => aqi = v),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: loading ? null : simulate,
                      icon: Icon(Icons.play_arrow),
                      label: Text("Simulate", style: GoogleFonts.assistant()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (growth.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Growth Curve (90 days):",
                    style: GoogleFonts.assistant(fontWeight: FontWeight.bold),
                  ),
                  if (ideal != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Ideal Conditions:",
                            style: GoogleFonts.assistant(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildIdealCard(
                                icon: Icons.thermostat,
                                label: "Temp",
                                value:
                                    "${ideal!['temp']?[0]}–${ideal!['temp']?[1]}°C",
                                color: Colors.orange,
                              ),
                              _buildIdealCard(
                                icon: Icons.water_drop,
                                label: "Humidity",
                                value:
                                    "${ideal!['humidity']?[0]}–${ideal!['humidity']?[1]}%",
                                color: Colors.lightBlue,
                              ),
                              _buildIdealCard(
                                icon: Icons.air,
                                label: "AQI",
                                value:
                                    "${ideal!['aqi']?[0]}–${ideal!['aqi']?[1]}",
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if ((result == "Your plant died!" ||
                          result == "Your plant is struggling.") &&
                      thriving != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Ideal score for the plant to thrive is: ${thriving!.toStringAsFixed(1)}',
                        style: GoogleFonts.assistant(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      "Your plant is thriving! Aim for an ideal score of ${thriving!.toStringAsFixed(1)} to stay healthy.",
                      style: GoogleFonts.assistant(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      height: 300, // Increased height from 200 to 300
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY:
                                growth.isEmpty
                                    ? 700
                                    : (growth.reduce((a, b) => a > b ? a : b) <=
                                            700
                                        ? 700
                                        : (growth.reduce(
                                                  (a, b) => a > b ? a : b,
                                                ) *
                                                1.1)
                                            .ceilToDouble()),

                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    return LineTooltipItem(
                                      spot.y.toStringAsFixed(2),
                                      GoogleFonts.assistant(
                                        color:
                                            Colors
                                                .white, // 🔴 Tooltip value color
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                              getTouchedSpotIndicator: (barData, indicators) {
                                return indicators.map((index) {
                                  return TouchedSpotIndicatorData(
                                    FlLine(color: themeColor, strokeWidth: 2),
                                    FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, barData, index) =>
                                              FlDotCirclePainter(
                                                radius: 6,
                                                color: Colors.white,
                                                strokeWidth: 3,
                                                strokeColor: themeColor,
                                              ),
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                axisNameWidget: Text(
                                  'Growth (cm or %)',
                                  style: GoogleFonts.assistant(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (value, meta) => Text(
                                        value.toInt().toString(),
                                        style: GoogleFonts.assistant(
                                          fontSize: 10,
                                        ),
                                      ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: Text(
                                  'Time (days)',
                                  style: GoogleFonts.assistant(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (value, meta) => Text(
                                        '${value.toInt()}d',
                                        style: GoogleFonts.assistant(
                                          fontSize: 10,
                                        ),
                                      ),
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: false,
                                ), // Hide top titles
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: false,
                                ), // Hide right titles
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: const Border(
                                left: BorderSide(),
                                bottom: BorderSide(),
                              ), // Hide top and right borders
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(
                                  growth.length,
                                  (i) => FlSpot(i * 3, growth[i]),
                                ),
                                isCurved: true,
                                color: themeColor,
                                barWidth: 3,
                                dotData: FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (result.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                result,
                style: GoogleFonts.assistant(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (reasons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      reasons
                          .map(
                            (r) => Text(
                              r,
                              style: GoogleFonts.assistant(color: Colors.red),
                            ),
                          )
                          .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdealCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 100,
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.assistant(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.assistant(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label: ${value.toStringAsFixed(1)}$unit",
          style: GoogleFonts.assistant(),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? (max - min).toInt(),
          label: "${value.toStringAsFixed(1)}$unit",
          onChanged: onChanged,
          activeColor: Colors.green.shade700,
          inactiveColor: Colors.green.shade100,
        ),
      ],
    );
  }
}
