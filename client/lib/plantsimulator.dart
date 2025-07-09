import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';


class PlantSimulatorPage extends StatefulWidget {
  const PlantSimulatorPage({super.key});

  @override
  State<PlantSimulatorPage> createState() => _PlantSimulatorPageState();
}

class _PlantSimulatorPageState extends State<PlantSimulatorPage> {
  // Environmental parameters
  double temp = 22;
  double humidity = 60;
  double aqi = 1;
  
  // Soil parameters
  double soilPH = 6.5;
  String soilType = "loamy";
  
  // Farm parameters
  double farmSize = 1.0; // hectares
  double budget = 5000; // USD
  String plantingMonth = "Spring";
  
  String plant = "Tomatoes";
  List<Map<String, dynamic>> growth = [];
  String result = "";
  List<String> reasons = [];
  bool loading = false;
  
  // Enhanced response data
  Map<String, dynamic>? farmingData;
  Map<String, dynamic>? economicData;
  Map<String, dynamic>? riskData;
  Map<String, dynamic>? environmentalData;
  Map<String, dynamic>? soilData;
  Map<String, dynamic>? growthData;
  Map<String, dynamic>? seasonalData;
  String? overallScore;
  String? statusColor;
  
  // All vegetables from CSV
  final List<String> csvVegetables = [
    "Asparagus", "Beans Lima", "Beans Snap", "Beets", "Broccoli", 
    "Cabbage", "Carrots", "Cauliflower", "Celery", "Chard Swiss",
    "Corn", "Cucumbers", "Eggplant", "Garlic", "Leeks", 
    "Lettuce", "Muskmelons (Cantaloupe)", "Okra", "Onions", "Parsley",
    "Parsnips", "Peas", "Peppers", "Pumpkins", "Radishes", 
    "Spinach", "Squash", "Tomatoes", "Turnips", "Watermelons"
  ];

  final List<String> soilTypes = ["loamy", "sandy", "clay", "sandy-loam", "clay-loam"];
  final List<String> plantingMonths = ["Spring", "Summer", "Fall", "Winter", "Early Spring", "Late Spring"];

  void simulateFarming() async {
    setState(() {
      loading = true;
      growth = [];
      result = "";
      reasons = [];
      farmingData = null;
      economicData = null;
      riskData = null;
      environmentalData = null;
      soilData = null;
      growthData = null;
      seasonalData = null;
      overallScore = null;
      statusColor = null;
    });

    final response = await http.post(
      Uri.parse('https://$ipAddress/api/simulate-vegetable-farming'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'plant': plant,
        'temp': temp,
        'humidity': humidity,
        'aqi': (aqi *50).round(),
        'soilPH': soilPH,
        'soilType': soilType,
        'farmSize': farmSize,
        'budget': budget,
        'plantingMonth': plantingMonth,
      }),
    );
    print(response.body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        growth = List<Map<String, dynamic>>.from(
          data['growth']['series'],
        ).map((e) => {
          'day': e['day'],
          'biomass': (e['biomass'] as num).toDouble(),
          'health': (e['healthIndex'] as num).toDouble()
        }).toList();
        
        result = data['result'];
        farmingData = data['farming'];
        economicData = data['economics'];
        riskData = data['risks'];
        environmentalData = data['environmental'];
        soilData = data['soil'];
        growthData = data['growth'];
        seasonalData = data['seasonal'];
        overallScore = data['overallScore'].toString();
        statusColor = data['statusColor'];
        
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
        title: Text("Smart Farmer Assistant", style: GoogleFonts.assistant()),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Vegetable Selection Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🌱 Crop Selection",
                      style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: plant,
                      decoration: InputDecoration(
                        labelText: 'Select Vegetable Crop',
                        labelStyle: GoogleFonts.assistant(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: Icon(Icons.agriculture),
                      ),
                      items: csvVegetables.map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, style: GoogleFonts.assistant()),
                      )).toList(),
                      onChanged: (v) => setState(() => plant = v!),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Environmental Conditions Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🌤️ Environmental Conditions",
                      style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    buildSlider(
                      label: "Temperature",
                      value: temp,
                      min: 0,
                      max: 40,
                      unit: "°C",
                      icon: Icons.thermostat,
                      onChanged: (v) => setState(() => temp = v),
                    ),
                    const SizedBox(height: 10),
                    buildSlider(
                      label: "Humidity",
                      value: humidity,
                      min: 0,
                      max: 100,
                      unit: "%",
                      icon: Icons.water_drop,
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
                      icon: Icons.air,
                      onChanged: (v) => setState(() => aqi = v),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Soil Analysis Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🌍 Soil Analysis",
                      style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    buildSlider(
                      label: "Soil pH",
                      value: soilPH,
                      min: 4.0,
                      max: 9.0,
                      unit: "",
                      icon: Icons.science,
                      onChanged: (v) => setState(() => soilPH = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: soilType,
                      decoration: InputDecoration(
                        labelText: 'Soil Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: Icon(Icons.landscape),
                      ),
                      items: soilTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type, style: GoogleFonts.assistant()),
                      )).toList(),
                      onChanged: (v) => setState(() => soilType = v!),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Farm Economics Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "💰 Farm Economics",
                      style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    buildSlider(
                      label: "Farm Size",
                      value: farmSize,
                      min: 0.1,
                      max: 10.0,
                      unit: "hectares",
                      icon: Icons.map,
                      onChanged: (v) => setState(() => farmSize = v),
                    ),
                    const SizedBox(height: 10),
                    buildSlider(
                      label: "Budget",
                      value: budget,
                      min: 1000,
                      max: 50000,
                      unit: "USD",
                      icon: Icons.attach_money,
                      onChanged: (v) => setState(() => budget = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: plantingMonth,
                      decoration: InputDecoration(
                        labelText: 'Planting Season',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      items: plantingMonths.map((month) => DropdownMenuItem(
                        value: month,
                        child: Text(month, style: GoogleFonts.assistant()),
                      )).toList(),
                      onChanged: (v) => setState(() => plantingMonth = v!),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Simulate Button
            ElevatedButton.icon(
              onPressed: loading ? null : simulateFarming,
              icon: Icon(Icons.analytics),
              label: Text("Analyze Farming Potential", style: GoogleFonts.assistant(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Results Section
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (growth.isNotEmpty) ...[
              
              // Overall Result Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                color: result.contains("thrive") ? Colors.green.shade50 : 
                       result.contains("struggle") ? Colors.orange.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        result.contains("thrive") ? Icons.check_circle : 
                        result.contains("struggle") ? Icons.warning : Icons.error,
                        size: 48,
                        color: result.contains("thrive") ? Colors.green : 
                               result.contains("struggle") ? Colors.orange : Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result,
                        style: GoogleFonts.assistant(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: result.contains("thrive") ? Colors.green.shade800 : 
                                 result.contains("struggle") ? Colors.orange.shade800 : Colors.red.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Overall Score Card
              buildOverallScoreCard(),
              
              const SizedBox(height: 16),
              
              // Environmental Suitability Analysis
              buildEnvironmentalSuitabilityCard(),
              
              const SizedBox(height: 16),
              
              // Seasonal Suitability Analysis
              buildSeasonalSuitabilityCard(),
              
              const SizedBox(height: 16),
              
              // Enhanced Soil Analysis
              buildSoilAnalysisCard(),
              
              const SizedBox(height: 16),
              
              // Economic Analysis
              buildEconomicAnalysisCard(),
              
              const SizedBox(height: 16),
              
              // Growth Chart
              buildGrowthChart(),
              
              const SizedBox(height: 16),
              
              // Planting Specifications
              buildPlantingSpecificationsCard(),
              
              const SizedBox(height: 16),
              
              // Risk Assessment
              buildRiskAssessmentCard(),
              
              const SizedBox(height: 16),
              
              // Enhanced Farming Recommendations
              buildFarmingRecommendationsCard(),
              
              const SizedBox(height: 16),
              
              // Harvest Planning
              buildHarvestPlanningCard(),
            ],
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
    required String unit,
    required ValueChanged<double> onChanged,
    required IconData icon,
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.green.shade600),
            const SizedBox(width: 8),
            Text(
              "$label: ${value.toStringAsFixed(1)}$unit",
              style: GoogleFonts.assistant(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: Colors.green.shade600,
        ),
      ],
    );
  }

  Widget buildEconomicAnalysisCard() {
    if (economicData == null) return Container();
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "💰 Economic Analysis",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEconomicMetric(
                    "Investment",
                    "\$${economicData?['costs']?['estimated_total']?.toStringAsFixed(0) ?? 'N/A'}",
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildEconomicMetric(
                    "Expected Revenue",
                    "\$${economicData?['returns']?['revenue']?.toStringAsFixed(0) ?? 'N/A'}",
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEconomicMetric(
                    "Profit",
                    "\$${economicData?['returns']?['profit']?.toStringAsFixed(0) ?? 'N/A'}",
                    Icons.attach_money,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildEconomicMetric(
                    "ROI",
                    "${economicData?['returns']?['roi'] ?? 'N/A'}%",
                    Icons.show_chart,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEconomicMetric(
                    "Profit Margin",
                    "${economicData?['returns']?['profitMargin'] ?? 'N/A'}%",
                    Icons.percent,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildEconomicMetric(
                    "Break Even",
                    economicData?['breakEven'] ?? 'N/A',
                    Icons.balance,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Market Demand: ${economicData?['marketDemand'] ?? 'N/A'}",
                      style: GoogleFonts.assistant(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: (economicData?['viability'] == "Economically viable") 
                    ? Colors.green.shade50 
                    : Colors.red.shade50,
              ),
              child: Row(
                children: [
                  Icon(
                    (economicData?['viability'] == "Economically viable") 
                        ? Icons.check_circle 
                        : Icons.warning,
                    color: (economicData?['viability'] == "Economically viable") 
                        ? Colors.green 
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    economicData?['viability'] ?? 'No data',
                    style: GoogleFonts.assistant(
                      fontWeight: FontWeight.w600,
                      color: (economicData?['viability'] == "Economically viable") 
                          ? Colors.green.shade800 
                          : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEconomicMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.assistant(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.assistant(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildGrowthChart() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📈 Growth Simulation",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: growth.isEmpty ? 1000 : 
                        (growth.map((e) => e['biomass'] as double).reduce((a, b) => a > b ? a : b) * 1.1),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Biomass Growth',
                        style: GoogleFonts.assistant(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: GoogleFonts.assistant(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Days',
                        style: GoogleFonts.assistant(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: GoogleFonts.assistant(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(left: BorderSide(), bottom: BorderSide()),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: growth.map((e) => FlSpot(
                        (e['day'] as num).toDouble(),
                        (e['biomass'] as num).toDouble(),
                      )).toList(),
                      isCurved: true,
                      color: Colors.green.shade600,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRiskAssessmentCard() {
    if (riskData == null) return Container();
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "⚠️ Risk Assessment",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRiskItem(
              "Disease Risk",
              riskData?['disease']?['level'] ?? 'Unknown',
              [
                "Common diseases: ${(riskData?['disease']?['commonDiseases'] as List?)?.join(', ') ?? 'N/A'}",
                ...(riskData?['disease']?['prevention'] as List?)?.cast<String>() ?? ['No prevention data available'],
              ],
              Icons.local_hospital,
            ),
            const SizedBox(height: 12),
            _buildRiskItem(
              "Weather Risk",
              riskData?['weather']?['level'] ?? 'Unknown',
              [riskData?['weather']?['mitigation'] ?? 'No mitigation data available'],
              Icons.cloud,
            ),
            const SizedBox(height: 12),
            _buildRiskItem(
              "Market Risk",
              riskData?['market']?['level'] ?? 'Unknown',
              [riskData?['market']?['advice'] ?? 'No market advice available'],
              Icons.trending_down,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskItem(String title, String level, List<dynamic> recommendations, IconData icon) {
    Color riskColor = level == "Low" ? Colors.green : 
                     level == "Medium" ? Colors.orange : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: riskColor.withValues(alpha: 0.1),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: riskColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.assistant(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: riskColor,
                ),
                child: Text(
                  level,
                  style: GoogleFonts.assistant(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: GoogleFonts.assistant(color: riskColor)),
                Expanded(
                  child: Text(
                    rec.toString(),
                    style: GoogleFonts.assistant(fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget buildFarmingRecommendationsCard() {
    if (farmingData == null) return Container();
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🚜 Farming Recommendations",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Irrigation Plan
            _buildRecommendationSection(
              "💧 Irrigation Plan",
              [
                "Water needed: ${farmingData?['irrigation']?['totalWaterNeeded']?.toStringAsFixed(0) ?? 'N/A'}mm",
                "Frequency: ${farmingData?['irrigation']?['frequency'] ?? 'N/A'}",
                "Estimated cost: \$${farmingData?['irrigation']?['cost']?.toStringAsFixed(0) ?? 'N/A'}",
                farmingData?['irrigation']?['method'] ?? 'No irrigation method specified',
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Enhanced Fertilization Plan
            _buildRecommendationSection(
              "🌱 Detailed Fertilization Plan",
              [
                "Total cost: \$${farmingData?['fertilization']?['cost']?.toStringAsFixed(0) ?? 'N/A'}",
                farmingData?['fertilization']?['cropSpecific'] ?? 'No crop-specific data',
                farmingData?['fertilization']?['soilAdjustment'] ?? 'No soil adjustment data',
                "Total NPK needed: ${farmingData?['fertilization']?['totalNutrients']?['nitrogen'] ?? 'N/A'}, ${farmingData?['fertilization']?['totalNutrients']?['phosphorus'] ?? 'N/A'}, ${farmingData?['fertilization']?['totalNutrients']?['potassium'] ?? 'N/A'}",
                "",
                "Application Schedule:",
                ...(farmingData?['fertilization']?['schedule'] as List?)
                    ?.cast<Map<String, dynamic>>()
                    .map((schedule) => "Week ${schedule['week'] ?? 'N/A'}: ${schedule['fertilizer'] ?? 'N/A'} - ${schedule['npk'] ?? 'N/A'} (${schedule['notes'] ?? 'No notes'})")
                    .toList() ?? ['No fertilization schedule available'],
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Companion Planting
            if ((farmingData?['companion_planting']?['beneficial'] as List?)?.isNotEmpty == true)
              _buildRecommendationSection(
                "🌿 Companion Planting",
                [
                  "Plant with: ${(farmingData?['companion_planting']?['beneficial'] as List?)?.join(', ') ?? 'N/A'}",
                  farmingData?['companion_planting']?['benefits'] ?? 'No companion planting benefits specified',
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.assistant(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: GoogleFonts.assistant(color: Colors.green.shade600)),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.assistant(fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget buildOverallScoreCard() {
    if (overallScore == null) return Container();
    
    double score = double.tryParse(overallScore!) ?? 0;
    Color scoreColor = score >= 80 ? Colors.green : 
                      score >= 60 ? Colors.orange : Colors.red;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "🎯 Overall Farming Score",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      "${score.toInt()}%",
                      style: GoogleFonts.assistant(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      "Success Rate",
                      style: GoogleFonts.assistant(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: scoreColor.withValues(alpha: 0.1),
                border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                score >= 80 ? "Excellent farming conditions!" :
                score >= 60 ? "Good farming potential with some challenges" :
                "Challenging conditions - consider alternatives",
                style: GoogleFonts.assistant(
                  fontWeight: FontWeight.w600,
                  color: scoreColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEnvironmentalSuitabilityCard() {
    if (environmentalData == null) return Container();
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🌤️ Environmental Suitability",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildEnvironmentalFactor(
              "Temperature",
              "${environmentalData?['temperature']?['current'] ?? 'N/A'}°C",
              "${environmentalData?['temperature']?['optimal']?[0] ?? 'N/A'}-${environmentalData?['temperature']?['optimal']?[1] ?? 'N/A'}°C",
              environmentalData?['temperature']?['suitable'] ?? false,
              environmentalData?['temperature']?['advice'] ?? "No data available",
              Icons.thermostat,
            ),
            const SizedBox(height: 12),
            _buildEnvironmentalFactor(
              "Humidity",
              "${environmentalData?['humidity']?['current'] ?? 'N/A'}%",
              "${environmentalData?['humidity']?['optimal']?[0] ?? 'N/A'}-${environmentalData?['humidity']?['optimal']?[1] ?? 'N/A'}%",
              environmentalData?['humidity']?['suitable'] ?? false,
              environmentalData?['humidity']?['advice'] ?? "No data available",
              Icons.water_drop,
            ),
            const SizedBox(height: 12),
            _buildEnvironmentalFactor(
              "Air Quality",
              "AQI ${environmentalData?['airQuality']?['current'] ?? 'N/A'}",
              "AQI ${environmentalData?['airQuality']?['optimal']?[0] ?? 'N/A'}-${environmentalData?['airQuality']?['optimal']?[1] ?? 'N/A'}",
              environmentalData?['airQuality']?['suitable'] ?? false,
              environmentalData?['airQuality']?['advice'] ?? "No data available",
              Icons.air,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalFactor(
    String factor,
    String current,
    String optimal,
    bool suitable,
    String advice,
    IconData icon,
  ) {
    Color statusColor = suitable ? Colors.green : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: statusColor.withValues(alpha: 0.1),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                factor,
                style: GoogleFonts.assistant(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Icon(
                suitable ? Icons.check_circle : Icons.warning,
                color: statusColor,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Current: ",
                style: GoogleFonts.assistant(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                current,
                style: GoogleFonts.assistant(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Text(
                "Optimal: ",
                style: GoogleFonts.assistant(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                optimal,
                style: GoogleFonts.assistant(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            advice,
            style: GoogleFonts.assistant(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget buildSoilAnalysisCard() {
    if (soilData == null) return Container();
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🌍 Enhanced Soil Analysis",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // pH Analysis
            _buildSoilFactor(
              "Soil pH",
              "${soilData?['pH']?['current'] ?? 'N/A'}",
              "${soilData?['pH']?['optimal']?[0] ?? 'N/A'}-${soilData?['pH']?['optimal']?[1] ?? 'N/A'}",
              soilData?['pH']?['suitable'] ?? false,
              soilData?['pH']?['adjustment'] ?? 'No adjustment data',
              Icons.science,
            ),
            
            const SizedBox(height: 12),
            
            // Soil Type
            _buildSoilFactor(
              "Soil Type",
              "${soilData?['type']?['current'] ?? 'N/A'}",
              (soilData?['type']?['preferred'] as List?)?.join(', ') ?? 'N/A',
              soilData?['type']?['suitable'] ?? false,
              soilData?['type']?['improvement'] ?? 'No improvement data',
              Icons.landscape,
            ),
            
            const SizedBox(height: 16),
            
            // Nutrient Requirements
            Text(
              "🌱 Nutrient Requirements (NPK)",
              style: GoogleFonts.assistant(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildNutrientIndicator(
                    "Nitrogen (N)",
                    soilData?['nutrients']?['nitrogen'] ?? 'N/A',
                    Colors.green,
                    Icons.grass,
                  ),
                ),
                Expanded(
                  child: _buildNutrientIndicator(
                    "Phosphorus (P)",
                    soilData?['nutrients']?['phosphorus'] ?? 'N/A',
                    Colors.orange,
                    Icons.energy_savings_leaf,
                  ),
                ),
                Expanded(
                  child: _buildNutrientIndicator(
                    "Potassium (K)",
                    soilData?['nutrients']?['potassium'] ?? 'N/A',
                    Colors.blue,
                    Icons.water_damage,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.brown.shade50,
                border: Border.all(color: Colors.brown.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.eco, color: Colors.brown.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Organic Matter: ${soilData?['nutrients']?['organicMatter'] ?? 'N/A'}",
                      style: GoogleFonts.assistant(
                        fontWeight: FontWeight.w600,
                        color: Colors.brown.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilFactor(
    String factor,
    String current,
    String optimal,
    bool suitable,
    String advice,
    IconData icon,
  ) {
    Color statusColor = suitable ? Colors.green : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: statusColor.withValues(alpha: 0.1),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                factor,
                style: GoogleFonts.assistant(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Icon(
                suitable ? Icons.check_circle : Icons.warning,
                color: statusColor,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Current: ",
                style: GoogleFonts.assistant(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                current,
                style: GoogleFonts.assistant(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                "Preferred: ",
                style: GoogleFonts.assistant(fontSize: 12, color: Colors.grey.shade600),
              ),
              Expanded(
                child: Text(
                  optimal,
                  style: GoogleFonts.assistant(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            advice,
            style: GoogleFonts.assistant(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientIndicator(String nutrient, String level, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            nutrient,
            style: GoogleFonts.assistant(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            level.toUpperCase(),
            style: GoogleFonts.assistant(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlantingSpecificationsCard() {
    if (farmingData == null) return Container();
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🌱 Planting Specifications",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Crop Category
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.category, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Text(
                    "Category: ",
                    style: GoogleFonts.assistant(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  Text(
                    farmingData?['planting']?['category'] ?? 'N/A',
                    style: GoogleFonts.assistant(
                      fontSize: 14,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Planting Specifications Grid
            Row(
              children: [
                Expanded(
                  child: _buildSpecificationItem(
                    "Planting Depth",
                    farmingData?['planting']?['depth'] ?? 'N/A',
                    Icons.height,
                    Colors.brown,
                  ),
                ),
                Expanded(
                  child: _buildSpecificationItem(
                    "Plant Spacing",
                    farmingData?['planting']?['spacing'] ?? 'N/A',
                    Icons.straighten,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Planting Seasons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      Text(
                        "Optimal Planting Seasons",
                        style: GoogleFonts.assistant(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: (farmingData?['planting']?['seasons'] as List?)
                        ?.map((season) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.orange.shade200,
                              ),
                              child: Text(
                                season.toString(),
                                style: GoogleFonts.assistant(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ))
                        .toList() ?? [Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text('No season data available'),
                        )],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificationItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.assistant(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: GoogleFonts.assistant(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildHarvestPlanningCard() {
    if (farmingData == null) return Container();
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🚜 Harvest Planning",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Harvest Timing
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.amber.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Estimated Harvest Date",
                          style: GoogleFonts.assistant(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        Text(
                          farmingData?['harvesting']?['estimatedDate'] ?? 'N/A',
                          style: GoogleFonts.assistant(
                            fontSize: 14,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Harvest Window and Storage
            Row(
              children: [
                Expanded(
                  child: _buildHarvestMetric(
                    "Harvest Window",
                    farmingData?['harvesting']?['window'] ?? 'N/A',
                    Icons.access_time,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildHarvestMetric(
                    "Storage Life",
                    farmingData?['harvesting']?['storageLife'] ?? 'N/A',
                    Icons.storage,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Harvest Indicators
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.teal.shade50,
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.teal.shade600),
                      const SizedBox(width: 8),
                      Text(
                        "Harvest Indicators",
                        style: GoogleFonts.assistant(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    farmingData?['harvesting']?['signs'] ?? 'No harvest indicators available',
                    style: GoogleFonts.assistant(
                      fontSize: 12,
                      color: Colors.teal.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHarvestMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.assistant(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: GoogleFonts.assistant(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildSeasonalSuitabilityCard() {
    if (seasonalData == null) return Container();
    
    bool isSuitable = seasonalData?['suitable'] ?? false;
    int score = seasonalData?['score'] ?? 0;
    String message = seasonalData?['message'] ?? 'No seasonal analysis available';
    String risk = seasonalData?['risk'] ?? 'Unknown';
    String selectedSeason = seasonalData?['selectedSeason'] ?? 'N/A';
    List<dynamic> optimalSeasons = seasonalData?['optimalSeasons'] ?? [];
    
    Color statusColor = isSuitable ? Colors.green : Colors.red;
    if (score >= 70) statusColor = Colors.orange;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📅 Seasonal Timing Analysis",
              style: GoogleFonts.assistant(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Current Selection vs Optimal
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: statusColor.withValues(alpha: 0.1),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        "Planting Season Analysis",
                        style: GoogleFonts.assistant(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: statusColor,
                        ),
                        child: Text(
                          "$score%",
                          style: GoogleFonts.assistant(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Selected Season
                  Row(
                    children: [
                      Text(
                        "Selected: ",
                        style: GoogleFonts.assistant(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.shade100,
                        ),
                        child: Text(
                          selectedSeason,
                          style: GoogleFonts.assistant(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Optimal Seasons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Optimal: ",
                        style: GoogleFonts.assistant(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          children: optimalSeasons.map((season) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.green.shade100,
                            ),
                            child: Text(
                              season.toString(),
                              style: GoogleFonts.assistant(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Risk Assessment
                  Row(
                    children: [
                      Icon(
                        risk == "Low" ? Icons.check_circle :
                        risk == "Medium" ? Icons.warning : Icons.error,
                        size: 16,
                        color: risk == "Low" ? Colors.green :
                               risk == "Medium" ? Colors.orange : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Risk: $risk",
                        style: GoogleFonts.assistant(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: risk == "Low" ? Colors.green :
                                 risk == "Medium" ? Colors.orange : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Analysis Message
                  Text(
                    message,
                    style: GoogleFonts.assistant(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
