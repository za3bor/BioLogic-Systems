import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CityDetailDialog extends StatelessWidget {
  final Map<String, dynamic> city;
  const CityDetailDialog({super.key, required this.city});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.location_city, color: Colors.green[800], size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city['name'],
                  style: GoogleFonts.lato(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                Text(
                  city['plant'] ?? 'Agricultural Analysis',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Suitability Score
              _buildOverallScoreCard(),
              SizedBox(height: 16),
              
              // Environmental Analysis
              _buildEnvironmentalAnalysis(),
              SizedBox(height: 16),
              
              // Soil Analysis
              _buildSoilAnalysis(),
              SizedBox(height: 16),
              
              // Seasonal Analysis
              _buildSeasonalAnalysis(),
              SizedBox(height: 16),
              
              // Risk Assessment
              _buildRiskAssessment(),
              SizedBox(height: 16),
              
              // Economic Analysis
              _buildEconomicAnalysis(),
              SizedBox(height: 16),
              
              // Farming Recommendations
              _buildFarmingRecommendations(),
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

  Widget _buildOverallScoreCard() {
    final score = city['overallScore'] ?? 0;
    final category = city['score'] ?? 'Unknown';
    final reason = city['reason'] ?? 'No analysis available';
    
    Color scoreColor = Colors.grey;
    IconData scoreIcon = Icons.help;
    
    switch (category.toLowerCase()) {
      case 'excellent':
        scoreColor = Colors.green[700]!;
        scoreIcon = Icons.star;
        break;
      case 'good':
        scoreColor = Colors.green;
        scoreIcon = Icons.thumb_up;
        break;
      case 'moderate':
        scoreColor = Colors.orange;
        scoreIcon = Icons.warning;
        break;
      case 'challenging':
        scoreColor = Colors.red[600]!;
        scoreIcon = Icons.error;
        break;
      case 'poor':
        scoreColor = Colors.red[900]!;
        scoreIcon = Icons.dangerous;
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [scoreColor.withValues(alpha: 0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(scoreIcon, color: scoreColor, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Suitability: ${category.toUpperCase()}',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        'Score: $score/100',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              reason,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalAnalysis() {
    final env = city['environmental'] ?? {};
    final temp = env['temperature'] ?? {};
    final humidity = env['humidity'] ?? {};
    final airQuality = env['airQuality'] ?? {};

    return _buildSectionCard(
      title: '🌡️ Environmental Conditions',
      children: [
        _buildFactorRow(
          'Temperature',
          '${temp['value']?.toStringAsFixed(1) ?? 'N/A'}°C',
          temp['suitable'] ?? false,
          'Optimal: ${temp['optimal']?[0] ?? 'N/A'}-${temp['optimal']?[1] ?? 'N/A'}°C',
        ),
        _buildFactorRow(
          'Humidity',
          '${humidity['value']?.toStringAsFixed(0) ?? 'N/A'}%',
          humidity['suitable'] ?? false,
          'Optimal: ${humidity['optimal']?[0] ?? 'N/A'}-${humidity['optimal']?[1] ?? 'N/A'}%',
        ),
        _buildFactorRow(
          'Air Quality',
          '${airQuality['value']?.toStringAsFixed(0) ?? 'N/A'} AQI',
          airQuality['suitable'] ?? false,
          'Optimal: ${airQuality['optimal']?[0] ?? 'N/A'}-${airQuality['optimal']?[1] ?? 'N/A'}',
        ),
        SizedBox(height: 8),
        Text(
          'Environmental Factor: ${((env['factor'] ?? 0) * 100).toStringAsFixed(1)}%',
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.green[700],
          ),
        ),
      ],
    );
  }

  Widget _buildSoilAnalysis() {
    final soil = city['soil'] ?? {};

    return _buildSectionCard(
      title: '🌱 Soil Analysis',
      children: [
        _buildFactorRow(
          'Soil Type',
          (soil['type'] ?? 'N/A').toString().replaceAll('-', ' ').toUpperCase(),
          soil['suitable'] ?? false,
          'Optimal: ${(soil['optimalTypes'] ?? []).join(', ')}',
        ),
        _buildFactorRow(
          'Soil pH',
          '${soil['pH']?.toStringAsFixed(1) ?? 'N/A'}',
          soil['suitable'] ?? false,
          'Optimal: ${soil['optimalPH']?[0] ?? 'N/A'}-${soil['optimalPH']?[1] ?? 'N/A'}',
        ),
      ],
    );
  }

  Widget _buildSeasonalAnalysis() {
    final seasonal = city['seasonal'] ?? {};

    return _buildSectionCard(
      title: '📅 Seasonal Analysis',
      children: [
        _buildFactorRow(
          'Current Season',
          seasonal['currentSeason'] ?? 'N/A',
          seasonal['suitable'] ?? false,
          'Factor: ${((seasonal['factor'] ?? 0) * 100).toStringAsFixed(1)}%',
        ),
        SizedBox(height: 8),
        Text(
          'Best Planting Seasons:',
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ((seasonal['bestSeasons'] ?? []) as List)
              .map((season) => Chip(
                    label: Text(
                      season.toString(),
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green[100],
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRiskAssessment() {
    final risks = city['risks'] ?? {};

    return _buildSectionCard(
      title: '⚠️ Risk Assessment',
      children: [
        _buildRiskRow('Disease Risk', risks['disease'] ?? 'Unknown'),
        _buildRiskRow('Weather Risk', risks['weather'] ?? 'Unknown'),
        if ((risks['commonDiseases'] ?? []).isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Common Diseases:',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: ((risks['commonDiseases'] ?? []) as List)
                .map((disease) => Chip(
                      label: Text(
                        disease.toString(),
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.red[100],
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildEconomicAnalysis() {
    final economics = city['economics'] ?? {};

    return _buildSectionCard(
      title: '💰 Economic Analysis',
      children: [
        _buildEconomicRow('Estimated Yield', '${economics['estimatedYield'] ?? 0} kg'),
        _buildEconomicRow('Total Costs', '\$${economics['totalCosts'] ?? 0}'),
        _buildEconomicRow('Gross Revenue', '\$${economics['grossRevenue'] ?? 0}'),
        _buildEconomicRow('Net Profit', '\$${economics['netProfit'] ?? 0}'),
        _buildEconomicRow('Profit Margin', '${economics['profitMargin'] ?? 0}%'),
        _buildEconomicRow('ROI', '${economics['roi'] ?? 0}%'),
        _buildEconomicRow('Break-even', '${economics['breakEven'] ?? 0} kg'),
      ],
    );
  }

  Widget _buildFarmingRecommendations() {
    final farming = city['farming'] ?? {};

    return _buildSectionCard(
      title: '🚜 Farming Information',
      children: [
        _buildInfoRow('Days to Maturity', '${farming['daysToMaturity'] ?? 'N/A'} days'),
        _buildInfoRow('Harvest Window', '${farming['harvestWindow'] ?? 'N/A'} days'),
        _buildInfoRow('Water Requirements', '${farming['waterRequirements'] ?? 'N/A'} mm'),
        if ((farming['companionPlants'] ?? []).isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Companion Plants:',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: ((farming['companionPlants'] ?? []) as List)
                .map((plant) => Chip(
                      label: Text(
                        plant.toString(),
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue[100],
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFactorRow(String label, String value, bool suitable, String optimal) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            suitable ? Icons.check_circle : Icons.cancel,
            color: suitable ? Colors.green : Colors.red,
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: $value',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  optimal,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskRow(String label, String risk) {
    Color riskColor = Colors.grey;
    IconData riskIcon = Icons.help;
    
    switch (risk.toLowerCase()) {
      case 'low':
        riskColor = Colors.green;
        riskIcon = Icons.check_circle;
        break;
      case 'medium':
        riskColor = Colors.orange;
        riskIcon = Icons.warning;
        break;
      case 'high':
        riskColor = Colors.red;
        riskIcon = Icons.error;
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(riskIcon, color: riskColor, size: 18),
          SizedBox(width: 8),
          Text(
            '$label: ${risk.toUpperCase()}',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEconomicRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
