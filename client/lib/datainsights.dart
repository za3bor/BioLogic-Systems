import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class DataInsightsPage extends StatefulWidget {
  const DataInsightsPage({super.key, required this.city});
  final String city;
  @override
  State<DataInsightsPage> createState() => _DataInsightsPageState();
}

class _DataInsightsPageState extends State<DataInsightsPage> {
  double? slope, intercept;
  List<Map<String, dynamic>> historicalData = [];
  String? regressionMessage;
  List<double>? finalTemps;
  double? finalMaxTemp;
  double? finalMinTemp;
  double? finalmaxxTemp;
  double? finalminxTemp;
  double? finalstep;
  List<double>? finaldisplayedTicks;
  bool isLoading = false;
  void runRegression() async {
    setState(() {
      isLoading = true;
    });
    final response = await http.get(
      Uri.parse(
        'https://$ipAddress/api/city-history?city=${Uri.encodeComponent(widget.city)}',
      ),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      final List<dynamic> rawData = res['data'];

      setState(() {
        slope = res['regression']['slope'];
        intercept = res['regression']['intercept'];
        regressionMessage = res['message'];
        historicalData =
            rawData
                .map<Map<String, dynamic>>(
                  (e) => {
                    'date': e['date'],
                    'temp': e['temp'],
                    'aqi': e['aqi'],
                  },
                )
                .toList();
        final temps =
            historicalData.map((e) => (e['temp'] as num).toDouble()).toList();
        final minTemp = temps.reduce((a, b) => a < b ? a : b);
        final maxTemp = temps.reduce((a, b) => a > b ? a : b);
        finalTemps = temps;
        finalMaxTemp = maxTemp;
        finalMinTemp = minTemp;
        final tempValues =
            historicalData.map((e) => (e['temp'] as num).toDouble()).toList();

        tempValues.sort();
        final minxTemp = tempValues.first;
        final maxxTemp = tempValues.last;

        // Generate 5 evenly spaced values (min, ..., max)
        final step = (maxxTemp - minxTemp) / 4;
        final displayedTicks = List.generate(
          5,
          (i) => (minxTemp + i * step).toDouble(),
        );
        finalminxTemp = minxTemp;
        finalmaxxTemp = maxxTemp;
        finalstep = step;
        finaldisplayedTicks = displayedTicks;
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  double computeMaxY() {
    if (historicalData.isEmpty) return 100;

    final aqiValues = historicalData.map((e) => (e['aqi'] as num).toDouble());
    final maxAqi = aqiValues.reduce((a, b) => a > b ? a : b);

    if (maxAqi <= 50) {
      return 50;
      // ignore: curly_braces_in_flow_control_structures
    } else if (maxAqi <= 80) {
      return 80;
    } else if (maxAqi <= 100) {
      return 100;
    }

    return (maxAqi * 1.1).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = Colors.green.shade700;
    final lightGreen = Colors.green.shade50;
    final darkGreen = Colors.green.shade900;

    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),

        title: Text(
          'AirWise Insights',
          style: GoogleFonts.openSans(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
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
              : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  Text(
                    'Regression Analysis',
                    style: GoogleFonts.openSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore how air quality (AQI) changes with temperature.',
                    style: GoogleFonts.openSans(
                      fontSize: 16,
                      color: darkGreen.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sample Data:',
                            style: GoogleFonts.openSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...historicalData.map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• AQI: ${e['aqi']}, Temp: ${e['temp']}°C',
                                style: GoogleFonts.openSans(
                                  fontSize: 14,
                                  color: darkGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: runRegression,
                    icon: const Icon(Icons.trending_up, color: Colors.white),
                    label: Text(
                      'Run Regression',
                      style: GoogleFonts.openSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (slope != null && intercept != null)
                    Card(
                      color: lightGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Regression Line:\nAQI = ${slope!.toStringAsFixed(2)} × Temp + ${intercept!.toStringAsFixed(2)}',
                          style: GoogleFonts.openSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: darkGreen,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  if (slope != null && intercept != null)
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: SizedBox(
                          height: 400,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: computeMaxY(),
                              minX: finalminxTemp,
                              maxX: finalmaxxTemp,
                              backgroundColor: lightGreen,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: 10,
                                verticalInterval: 2,
                                getDrawingHorizontalLine:
                                    (value) => FlLine(
                                      color: Colors.green.shade200,
                                      strokeWidth: 1,
                                    ),
                                getDrawingVerticalLine:
                                    (value) => FlLine(
                                      color: Colors.green.shade200,
                                      strokeWidth: 1,
                                    ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 10,
                                    getTitlesWidget:
                                        (value, meta) => Text(
                                          value.toInt().toString(),
                                          style: GoogleFonts.openSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: primaryGreen,
                                          ),
                                        ),
                                    reservedSize: 25,
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: false,
                                  ), // Hide right Y axis
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: false,
                                  ), // Hide top X axis
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval:
                                        finalstep ?? 1, // fallback to 1 if null
                                    getTitlesWidget: (value, meta) {
                                      if (finaldisplayedTicks == null) {
                                        return const SizedBox.shrink();
                                      }
                                      const double tolerance = 0.01;
                                      final match = finaldisplayedTicks!.any(
                                        (tick) =>
                                            (tick - value).abs() < tolerance,
                                      );
                                      if (match) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            value.toStringAsFixed(1),
                                            style: GoogleFonts.openSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: primaryGreen,
                                            ),
                                          ),
                                        );
                                      } else {
                                        return const SizedBox.shrink();
                                      }
                                    },
                                    reservedSize: 28,
                                  ),
                                ),
                              ),

                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 2,
                                ),
                              ),
                              lineBarsData: [
                                // Data points as dots
                                LineChartBarData(
                                  spots:
                                      historicalData
                                          .map(
                                            (e) => FlSpot(
                                              (e['temp'] as num).toDouble(),
                                              (e['aqi'] as num).toDouble(),
                                            ),
                                          )
                                          .toList(),
                                  isCurved: false,
                                  color: Colors.transparent,
                                  barWidth: 0,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) =>
                                            FlDotCirclePainter(
                                              radius: 5,
                                              color: primaryGreen,
                                              strokeWidth: 1.5,
                                              strokeColor: Colors.white,
                                            ),
                                  ),
                                  belowBarData: BarAreaData(show: false),
                                ),

                                // Regression line
                                LineChartBarData(
                                  spots: [
                                    FlSpot(
                                      finalMinTemp!,
                                      slope! * finalMinTemp! + intercept!,
                                    ),
                                    FlSpot(
                                      finalMaxTemp!,
                                      slope! * finalMaxTemp! + intercept!,
                                    ),
                                  ],
                                  isCurved: false,
                                  color: Colors.blueGrey.shade700,
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
                                ),
                              ],
                              // Tooltips for dots
                              lineTouchData: LineTouchData(
                                enabled: true,
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      return LineTooltipItem(
                                        'Temp: ${spot.x.toStringAsFixed(1)}°C\nAQI: ${spot.y.toStringAsFixed(1)}',
                                        GoogleFonts.openSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                                handleBuiltInTouches: true,
                                touchCallback: (event, response) {},
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (regressionMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.green.shade800,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  regressionMessage!,
                                  style: GoogleFonts.openSans(
                                    fontSize: 15,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
    );
  }
}
