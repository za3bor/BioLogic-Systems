import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CityDetailDialog extends StatelessWidget {
  final Map<String, dynamic> city;
  const CityDetailDialog({super.key, required this.city});

  @override
  Widget build(BuildContext context) {
    final growthSeries = List<Map<String, dynamic>>.from(city['growthSeries']);
    final weatherSeries = List<Map<String, dynamic>>.from(
      city['weatherSeries'],
    );
    final aqiSeries = List<Map<String, dynamic>>.from(city['aqiSeries']);

    return AlertDialog(
      backgroundColor: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        city['name'],
        style: GoogleFonts.lato(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.green[800],
        ),
      ),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('🏷️ Suitability'),
              const SizedBox(height: 6),
              Text(
                '${city['score']} (${city['reason']})',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _infoChip(
                    'Avg Temp',
                    '${city['avgTemp'].toStringAsFixed(1)}°C',
                    Icons.thermostat,
                  ),
                  _infoChip(
                    'Humidity',
                    '${city['avgHumidity'].toStringAsFixed(0)}%',
                    Icons.water_drop,
                  ),
                  _infoChip(
                    'AQI',
                    '${city['avgAqi'].toStringAsFixed(1)}',
                    Icons.air,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionTitle('🌱 Simulated Crop Growth'),
              const SizedBox(height: 10),
              _buildChart(
                spots:
                    growthSeries
                        .map(
                          (e) => FlSpot(
                            (e['t'] as num).toDouble(),
                            (e['N'] as num).toDouble(),
                          ),
                        )
                        .toList(),
                color: Colors.green,
                height: 180,
                yLabel: 'Growth',
                xLabelBuilder:
                    (v) => Text(
                      '${v.toInt()}d',
                      style: GoogleFonts.roboto(fontSize: 10),
                    ),
              ),
              const SizedBox(height: 24),

              _sectionTitle('📊 Weather & AQI Trends'),
              const SizedBox(height: 10),
              _buildMultiChart(weatherSeries, aqiSeries),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.lato(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey[800],
      ),
    );
  }

  Widget _infoChip(String label, String value, IconData icon) {
    return Chip(
      backgroundColor: Colors.grey.shade100,
      avatar: Icon(icon, size: 18, color: Colors.grey.shade700),
      label: Text(
        '$label: $value',
        style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildChart({
    required List<FlSpot> spots,
    required Color color,
    required double height,
    required String yLabel,
    required Widget Function(double) xLabelBuilder,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget:
                        (value, meta) => Text(
                          '${value.toInt()}d',
                          style: TextStyle(fontSize: 10),
                        ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: color,
                  dotData: FlDotData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        spot.y.toStringAsFixed(2),
                        TextStyle(
                          color:
                              Colors
                                  .white, // 👈 Change this to your desired color
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiChart(
    List<Map<String, dynamic>> weatherSeries,
    List<Map<String, dynamic>> aqiSeries,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30, // enough space for label
                        getTitlesWidget: (value, meta) {
                          final billions = value / 1e9;
                          String label;

                          if (billions >= 1) {
                            label =
                                '${billions.toStringAsFixed(1)}B'; // e.g., 1.2B
                          } else {
                            label =
                                value
                                    .toInt()
                                    .toString(); // fallback to normal number if less than 1 billion
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              label,
                              style: GoogleFonts.roboto(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots:
                          weatherSeries
                              .map(
                                (e) => FlSpot(
                                  (e['dt'] as num).toDouble(),
                                  (e['temp'] as num?)?.toDouble() ?? 0,
                                ),
                              )
                              .toList(),
                      isCurved: true,
                      barWidth: 2.5,
                      color: Colors.orange,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots:
                          aqiSeries
                              .map(
                                (e) => FlSpot(
                                  (e['dt'] as num).toDouble(),
                                  (e['aqi'] as num?)?.toDouble() ?? 0,
                                ),
                              )
                              .toList(),
                      isCurved: true,
                      barWidth: 2.5,
                      color: Colors.blue,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.orange),
                Text('Temp', style: GoogleFonts.roboto(fontSize: 13)),
                const SizedBox(width: 20),
                _legendDot(Colors.blue),
                Text('AQI', style: GoogleFonts.roboto(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
