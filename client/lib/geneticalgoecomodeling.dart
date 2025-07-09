import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:airwise/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

class GeneticAlgoEcomodelingPage extends StatefulWidget {
  const GeneticAlgoEcomodelingPage({super.key});

  @override
  State<GeneticAlgoEcomodelingPage> createState() =>
      _GeneticAlgoEcomodelingPageState();
}

class _GeneticAlgoEcomodelingPageState
    extends State<GeneticAlgoEcomodelingPage> {
  // GA Parameters
  int populationSize = 50;
  int generations = 100;
  double crossoverRate = 0.8;
  double mutationRate = 0.05;
  int currentGeneration = 0;
  bool isRunning = false;

  // Farm Configuration
  double farmSize = 10.0; // hectares
  double budget = 50000.0; // USD
  double waterAvailable = 1000.0; // cubic meters
  String soilType = 'Loamy';
  String climateZone = 'Temperate';

  // Optimization Objectives
  bool optimizeYield = true;
  bool optimizeSustainability = true;
  bool optimizeProfitability = true;
  bool optimizeWaterEfficiency = true;
  bool optimizeDiseaseResistance = true;

  // Results
  List<EcoChromosome> population = [];
  List<double> fitnessHistory = [];
  List<double> sustainabilityHistory = [];
  List<double> yieldHistory = [];
  EcoChromosome? bestSolution;

  // Server optimization results
  Map<String, dynamic> _optimizationMetrics = {};
  List<String> _recommendations = [];

  // UI State
  String selectedOptimizationMode = 'Multi-Objective';
  bool showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    _initializePopulation();
  }

  void _initializePopulation() {
    population.clear();
    Random random = Random();

    for (int i = 0; i < populationSize; i++) {
      EcoChromosome chromosome = EcoChromosome(
        crops: _generateRandomCrops(random),
        waterAllocation: List.generate(5, (_) => random.nextDouble() * 100),
        fertilizerAllocation: List.generate(5, (_) => random.nextDouble() * 50),
        landUse: List.generate(5, (_) => random.nextDouble() * farmSize / 5),
        plantingSchedule: List.generate(5, (_) => random.nextInt(12) + 1),
        pesticidesUse: List.generate(5, (_) => random.nextDouble() * 10),
      );
      chromosome.fitness = _calculateFitness(chromosome);
      population.add(chromosome);
    }

    // Update best solution after initializing population
    if (population.isNotEmpty) {
      population.sort((a, b) => b.fitness.compareTo(a.fitness));
      bestSolution = population.first;
    }
  }

  List<String> _generateRandomCrops(Random random) {
    List<String> availableCrops = [
      'Tomatoes',
      'Carrots',
      'Lettuce',
      'Corn',
      'Soybeans',
      'Wheat',
      'Peppers',
      'Cucumbers',
      'Onions',
      'Potatoes',
    ];
    availableCrops.shuffle(random);
    return availableCrops.take(5).toList();
  }

  double _calculateFitness(EcoChromosome chromosome) {
    double yieldScore = _calculateYieldScore(chromosome);
    double sustainabilityScore = _calculateSustainabilityScore(chromosome);
    double profitabilityScore = _calculateProfitabilityScore(chromosome);
    double waterEfficiencyScore = _calculateWaterEfficiencyScore(chromosome);
    double diseaseResistanceScore = _calculateDiseaseResistanceScore(
      chromosome,
    );

    double fitness = 0.0;
    int objectiveCount = 0;

    if (optimizeYield) {
      fitness += yieldScore;
      objectiveCount++;
    }
    if (optimizeSustainability) {
      fitness += sustainabilityScore;
      objectiveCount++;
    }
    if (optimizeProfitability) {
      fitness += profitabilityScore;
      objectiveCount++;
    }
    if (optimizeWaterEfficiency) {
      fitness += waterEfficiencyScore;
      objectiveCount++;
    }
    if (optimizeDiseaseResistance) {
      fitness += diseaseResistanceScore;
      objectiveCount++;
    }

    return objectiveCount > 0 ? fitness / objectiveCount : 0.0;
  }

  double _calculateYieldScore(EcoChromosome chromosome) {
    double totalYield = 0.0;
    double maxPossibleYield = 0.0;

    for (int i = 0; i < chromosome.crops.length; i++) {
      String crop = chromosome.crops[i];
      double landArea = chromosome.landUse[i];
      double waterUse = chromosome.waterAllocation[i]; // mm/season
      double fertilizerUse = chromosome.fertilizerAllocation[i]; // kg N/ha

      // Get crop-specific parameters
      Map<String, double> cropData = _getCropParameters(crop);
      double maxYield = cropData['maxYield']!; // tonnes/ha
      double optimalWater = cropData['waterRequirement']!; // mm/season
      double optimalNitrogen = cropData['nitrogenRequirement']!; // kg N/ha

      // Water stress factor (Doorenbos & Kassam model)
      double waterStressFactor = _calculateWaterStressFactor(
        waterUse,
        optimalWater,
      );

      // Nutrient response factor (Mitscherlich-Baule model)
      double nutrientFactor = _calculateNutrientResponseFactor(
        fertilizerUse,
        optimalNitrogen,
      );

      // Climate and soil stress factors
      double climateFactor = _getClimateFactor(crop);
      double soilFactor = _getSoilFactor(crop);

      // Actual yield using limiting factor principle
      double actualYield =
          maxYield *
          waterStressFactor *
          nutrientFactor *
          climateFactor *
          soilFactor;

      totalYield += actualYield * landArea;
      maxPossibleYield += maxYield * landArea;
    }

    return maxPossibleYield > 0
        ? (totalYield / maxPossibleYield).clamp(0.0, 1.0)
        : 0.0;
  }

  // Doorenbos & Kassam water-yield relationship
  double _calculateWaterStressFactor(double actualWater, double optimalWater) {
    if (actualWater >= optimalWater) {
      // Excess water reduces yield due to waterlogging
      double excessRatio = actualWater / optimalWater;
      return (2.0 - excessRatio).clamp(0.3, 1.0);
    } else {
      // Water deficit reduces yield linearly
      double deficitRatio = actualWater / optimalWater;
      return (0.2 + 0.8 * deficitRatio).clamp(0.2, 1.0);
    }
  }

  // Mitscherlich-Baule nutrient response model
  double _calculateNutrientResponseFactor(double actualN, double optimalN) {
    // Diminishing returns curve: Y = 1 - exp(-c * N)
    double c = 0.03; // Response coefficient
    double relativeN = actualN / optimalN;

    if (relativeN <= 1.0) {
      return 1.0 - math.exp(-c * actualN);
    } else {
      // Excess fertilizer reduces efficiency and can harm yield
      double excess = relativeN - 1.0;
      double maxResponse = 1.0 - math.exp(-c * optimalN);
      return (maxResponse * (1.0 - 0.2 * excess)).clamp(0.4, maxResponse);
    }
  }

  double _calculateSustainabilityScore(EcoChromosome chromosome) {
    double totalPesticides = chromosome.pesticidesUse.reduce((a, b) => a + b);
    double totalFertilizer = chromosome.fertilizerAllocation.reduce(
      (a, b) => a + b,
    );
    double totalWater = chromosome.waterAllocation.reduce((a, b) => a + b);

    // Lower chemical use = higher sustainability
    double pesticideScore = 1.0 - (totalPesticides / 50.0).clamp(0.0, 1.0);
    double fertilizerScore = 1.0 - (totalFertilizer / 250.0).clamp(0.0, 1.0);
    double waterScore = 1.0 - (totalWater / 500.0).clamp(0.0, 1.0);

    return (pesticideScore + fertilizerScore + waterScore) / 3.0;
  }

  double _calculateProfitabilityScore(EcoChromosome chromosome) {
    double totalRevenue = 0.0;
    double totalCost = 0.0;

    for (int i = 0; i < chromosome.crops.length; i++) {
      String crop = chromosome.crops[i];
      double landArea = chromosome.landUse[i];
      double waterUse = chromosome.waterAllocation[i];
      double fertilizerUse = chromosome.fertilizerAllocation[i];
      double pesticideUse = chromosome.pesticidesUse[i];

      // Revenue calculation
      double yield = _getCropBaseYield(crop) * landArea;
      double price = _getCropPrice(crop);
      totalRevenue += yield * price;

      // Cost calculation
      totalCost += landArea * 100; // Land preparation cost
      totalCost += waterUse * 2; // Water cost
      totalCost += fertilizerUse * 15; // Fertilizer cost
      totalCost += pesticideUse * 25; // Pesticide cost
    }

    double profit = totalRevenue - totalCost;
    return (profit / budget).clamp(0.0, 1.0);
  }

  double _calculateWaterEfficiencyScore(EcoChromosome chromosome) {
    double totalWater = chromosome.waterAllocation.reduce((a, b) => a + b);
    double yieldScore = _calculateYieldScore(chromosome);

    if (totalWater == 0) return 0.0;

    double efficiency = (yieldScore * 1000) / totalWater;
    return efficiency.clamp(0.0, 1.0);
  }

  double _calculateDiseaseResistanceScore(EcoChromosome chromosome) {
    double diversityScore = 0.0;
    Set<String> uniqueCrops = chromosome.crops.toSet();
    diversityScore = uniqueCrops.length / chromosome.crops.length;

    double pesticideReduction =
        1.0 -
        (chromosome.pesticidesUse.reduce((a, b) => a + b) / 50.0).clamp(
          0.0,
          1.0,
        );

    return (diversityScore + pesticideReduction) / 2.0;
  }

  double _getCropBaseYield(String crop) {
    Map<String, double> yields = {
      'Tomatoes': 45.0,
      'Carrots': 35.0,
      'Lettuce': 25.0,
      'Corn': 55.0,
      'Soybeans': 30.0,
      'Wheat': 40.0,
      'Peppers': 20.0,
      'Cucumbers': 35.0,
      'Onions': 40.0,
      'Potatoes': 50.0,
    };
    return yields[crop] ?? 30.0;
  }

  double _getCropPrice(String crop) {
    Map<String, double> prices = {
      'Tomatoes': 2.5,
      'Carrots': 1.8,
      'Lettuce': 3.2,
      'Corn': 1.2,
      'Soybeans': 2.0,
      'Wheat': 1.5,
      'Peppers': 4.0,
      'Cucumbers': 2.8,
      'Onions': 1.6,
      'Potatoes': 1.4,
    };
    return prices[crop] ?? 2.0;
  }

  void _runGeneticAlgorithm() async {
    setState(() {
      isRunning = true;
      currentGeneration = 0;
      fitnessHistory.clear();
      sustainabilityHistory.clear();
      yieldHistory.clear();
    });

    try {
      // Prepare request data for server-side genetic algorithm
      final requestData = {
        'farmConfig': {
          'farmSize': farmSize,
          'budget': budget,
          'soilType': soilType,
          'climateZone': climateZone,
        },
        'objectives': {
          'optimizeYield': optimizeYield,
          'optimizeProfitability': optimizeProfitability,
          'optimizeSustainability': optimizeSustainability,
          'optimizeWaterEfficiency': optimizeWaterEfficiency,
          'optimizeDiseaseResistance': optimizeDiseaseResistance,
        },
        'gaParameters': {
          'populationSize': populationSize,
          'generations': generations,
          'crossoverRate': crossoverRate,
          'mutationRate': mutationRate,
        },
      };

      // Call server-side genetic optimization
      final response = await http.post(
        Uri.parse('https://$ipAddress/api/genetic-optimization'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final results = data['results'];

          // Validate server response structure
          if (results == null ||
              results['bestSolution'] == null ||
              results['convergenceData'] == null ||
              results['metrics'] == null) {
            throw Exception('Invalid server response structure');
          }

          // Update UI with server results
          setState(() {
            // Create best solution chromosome from server response
            final bestSolutionData = results['bestSolution'];
            bestSolution = EcoChromosome(
              crops: List<String>.from(bestSolutionData['crops']),
              landUse:
                  (bestSolutionData['landAllocation'] as List)
                      .map((e) => (e as num).toDouble())
                      .toList(),
              waterAllocation:
                  (bestSolutionData['waterAllocation'] as List)
                      .map((e) => (e as num).toDouble())
                      .toList(),
              fertilizerAllocation:
                  (bestSolutionData['fertilizerAllocation'] as List)
                      .map((e) => (e as num).toDouble())
                      .toList(),
              pesticidesUse:
                  (bestSolutionData['pesticidesUse'] as List)
                      .map((e) => (e as num).toDouble())
                      .toList(),
              plantingSchedule: List.generate(
                bestSolutionData['crops'].length,
                (i) => 1,
              ),
              fitness: (bestSolutionData['fitness'] as num).toDouble(),
            );

            // Update convergence history
            final convergenceData = results['convergenceData'];
            fitnessHistory =
                (convergenceData['fitnessHistory'] as List)
                    .map((e) => (e as num).toDouble())
                    .toList();
            sustainabilityHistory =
                (convergenceData['sustainabilityHistory'] as List)
                    .map((e) => (e as num).toDouble())
                    .toList();
            yieldHistory =
                (convergenceData['yieldHistory'] as List)
                    .map((e) => (e as num).toDouble())
                    .toList();

            currentGeneration = generations;

            // Store metrics for display
            _optimizationMetrics = results['metrics'];
            _recommendations = List<String>.from(results['recommendations']);

            // print('✅ Genetic optimization completed successfully!');
            // print('Best fitness: ${bestSolution!.fitness.toStringAsFixed(4)}');
            // print('Total yield: ${_optimizationMetrics['totalYield']} tonnes');
            // print('Profitability: ${_optimizationMetrics['profitability']}');
          });
        } else {
          throw Exception('Optimization failed on server');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      //print('❌ Genetic optimization error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Optimization failed: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isRunning = false;
      });
    }
  }

  // Old local genetic algorithm functions removed - now using server-side optimization

  Map<String, double> _getCropParameters(String crop) {
    // Match server-side crop database for consistency
    final cropDB = {
      'Wheat': {
        'maxYield': 8.5,
        'waterRequirement': 450.0,
        'nitrogenRequirement': 150.0,
      },
      'Corn': {
        'maxYield': 12.0,
        'waterRequirement': 600.0,
        'nitrogenRequirement': 200.0,
      },
      'Rice': {
        'maxYield': 9.5,
        'waterRequirement': 1200.0,
        'nitrogenRequirement': 120.0,
      },
      'Soybeans': {
        'maxYield': 4.5,
        'waterRequirement': 500.0,
        'nitrogenRequirement': 80.0,
      },
      'Tomatoes': {
        'maxYield': 75.0,
        'waterRequirement': 700.0,
        'nitrogenRequirement': 250.0,
      },
      'Potatoes': {
        'maxYield': 45.0,
        'waterRequirement': 550.0,
        'nitrogenRequirement': 180.0,
      },
      'Cotton': {
        'maxYield': 2.5,
        'waterRequirement': 800.0,
        'nitrogenRequirement': 160.0,
      },
      'Sugarcane': {
        'maxYield': 85.0,
        'waterRequirement': 1500.0,
        'nitrogenRequirement': 200.0,
      },
    };
    return cropDB[crop] ?? cropDB['Wheat']!;
  }

  double _getClimateFactor(String crop) {
    // Climate adaptation factor based on current climate zone
    final climateAdaptation = {
      'Temperate': ['Wheat', 'Corn', 'Potatoes', 'Soybeans'],
      'Tropical': ['Rice', 'Sugarcane', 'Corn', 'Soybeans'],
      'Arid': ['Cotton', 'Wheat'],
      'Mediterranean': ['Wheat', 'Tomatoes', 'Potatoes'],
    };

    return climateAdaptation[climateZone]?.contains(crop) == true ? 0.95 : 0.7;
  }

  double _getSoilFactor(String crop) {
    // Soil compatibility factor
    final soilPreference = {
      'Loamy': ['Wheat', 'Corn', 'Tomatoes', 'Soybeans', 'Potatoes'],
      'Clayey': ['Rice', 'Wheat', 'Cotton', 'Sugarcane'],
      'Sandy': ['Potatoes', 'Soybeans', 'Tomatoes'],
      'Silty': ['Corn', 'Rice'],
    };

    return soilPreference[soilType]?.contains(crop) == true ? 0.9 : 0.7;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Text(
          'Genetic Algorithm Ecomodeling',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 6,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Farm Configuration Card
          _buildFarmConfigCard(),
          SizedBox(height: 16),

          // Optimization Objectives Card
          _buildObjectivesCard(),
          SizedBox(height: 16),

          // GA Parameters Card
          _buildParametersCard(),
          SizedBox(height: 16),

          // Control Buttons
          _buildControlButtons(),
          SizedBox(height: 16),

          // Progress Card
          if (currentGeneration > 0) _buildProgressCard(),
          if (currentGeneration > 0) SizedBox(height: 16),

          // Charts
          if (fitnessHistory.isNotEmpty) _buildChartsCard(),
          if (fitnessHistory.isNotEmpty) SizedBox(height: 16),

          // Best Solution Card
          if (bestSolution != null) _buildBestSolutionCard(),
        ],
      ),
    );
  }

  Widget _buildFarmConfigCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🚜 Farm Configuration',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Farm Size (ha)',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: farmSize,
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        label: farmSize.toStringAsFixed(1),
                        onChanged: (value) => setState(() => farmSize = value),
                        activeColor: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget (\$)',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: budget,
                        min: 10000.0,
                        max: 200000.0,
                        divisions: 190,
                        label: '\$${budget.toStringAsFixed(0)}',
                        onChanged: (value) => setState(() => budget = value),
                        activeColor: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: soilType,
                    decoration: InputDecoration(
                      labelText: 'Soil Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items:
                        ['Clayey', 'Loamy', 'Sandy', 'Silty']
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => soilType = value!),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: climateZone,
                    decoration: InputDecoration(
                      labelText: 'Climate Zone',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items:
                        ['Tropical', 'Temperate', 'Arid', 'Mediterranean']
                            .map(
                              (zone) => DropdownMenuItem(
                                value: zone,
                                child: Text(zone),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => climateZone = value!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectivesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 Optimization Objectives',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildObjectiveCheckbox(
                  'Maximize Yield',
                  optimizeYield,
                  (value) => setState(() => optimizeYield = value!),
                ),
                _buildObjectiveCheckbox(
                  'Sustainability',
                  optimizeSustainability,
                  (value) => setState(() => optimizeSustainability = value!),
                ),
                _buildObjectiveCheckbox(
                  'Profitability',
                  optimizeProfitability,
                  (value) => setState(() => optimizeProfitability = value!),
                ),
                _buildObjectiveCheckbox(
                  'Water Efficiency',
                  optimizeWaterEfficiency,
                  (value) => setState(() => optimizeWaterEfficiency = value!),
                ),
                _buildObjectiveCheckbox(
                  'Disease Resistance',
                  optimizeDiseaseResistance,
                  (value) => setState(() => optimizeDiseaseResistance = value!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectiveCheckbox(
    String title,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: value ? Colors.green.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? Colors.green.shade700 : Colors.grey.shade300,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green.shade700,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }

  Widget _buildParametersCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '⚙️ Genetic Algorithm Parameters',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed:
                      () => setState(
                        () => showAdvancedOptions = !showAdvancedOptions,
                      ),
                  child: Text(
                    showAdvancedOptions ? 'Hide Advanced' : 'Show Advanced',
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Population Size',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: populationSize.toDouble(),
                        min: 20.0,
                        max: 200.0,
                        divisions: 18,
                        label: populationSize.toString(),
                        onChanged:
                            (value) =>
                                setState(() => populationSize = value.round()),
                        activeColor: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generations',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: generations.toDouble(),
                        min: 10.0,
                        max: 500.0,
                        divisions: 49,
                        label: generations.toString(),
                        onChanged:
                            (value) =>
                                setState(() => generations = value.round()),
                        activeColor: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (showAdvancedOptions) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crossover Rate',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: crossoverRate,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: crossoverRate.toStringAsFixed(1),
                          onChanged:
                              (value) => setState(() => crossoverRate = value),
                          activeColor: Colors.green.shade700,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mutation Rate',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: mutationRate,
                          min: 0.01,
                          max: 0.2,
                          divisions: 19,
                          label: mutationRate.toStringAsFixed(2),
                          onChanged:
                              (value) => setState(() => mutationRate = value),
                          activeColor: Colors.green.shade700,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isRunning ? null : _runGeneticAlgorithm,
            icon: Icon(isRunning ? Icons.hourglass_empty : Icons.play_arrow),
            label: Text(
              isRunning ? 'Running...' : 'Start Optimization',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              isRunning = false;
              _initializePopulation();
              currentGeneration = 0;
              fitnessHistory.clear();
              sustainabilityHistory.clear();
              yieldHistory.clear();
            });
          },
          icon: Icon(Icons.refresh),
          label: Text(
            'Reset',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    double progress = currentGeneration / generations;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 Optimization Progress',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Generation $currentGeneration / $generations'),
                Text('${(progress * 100).toStringAsFixed(1)}%'),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
            ),

            if (bestSolution != null) ...[
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip(
                    'Fitness',
                    bestSolution!.fitness.toStringAsFixed(3),
                    Colors.blue,
                  ),
                  if (_optimizationMetrics.isNotEmpty) ...[
                    _buildStatChip(
                      'Sustainability',
                      _optimizationMetrics['sustainability'].toString(),
                      Colors.green,
                    ),
                    _buildStatChip(
                      'Yield Score',
                      _optimizationMetrics.containsKey('totalYield')
                          ? ((double.tryParse(
                                        _optimizationMetrics['totalYield']
                                            .toString(),
                                      ) ??
                                      0.0) /
                                  (farmSize * 10))
                              .toStringAsFixed(3)
                          : '0.000',
                      Colors.orange,
                    ),
                  ] else ...[
                    _buildStatChip('Preparing...', '---', Colors.green),
                    _buildStatChip('Calculating...', '---', Colors.orange),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(label, style: GoogleFonts.nunito(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildChartsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Evolution Progress',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),

            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots:
                          fitnessHistory
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots:
                          sustainabilityHistory
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots:
                          yieldHistory
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Fitness', Colors.blue),
                _buildLegendItem('Sustainability', Colors.green),
                _buildLegendItem('Yield', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        SizedBox(width: 8),
        Text(label, style: GoogleFonts.nunito(fontSize: 12)),
      ],
    );
  }

  Widget _buildBestSolutionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 Best Solution Found',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),

            Text(
              'Crop Selection & Allocation:',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),

            ...bestSolution!.crops.asMap().entries.map((entry) {
              int index = entry.key;
              String crop = entry.value;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        crop,
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${bestSolution!.landUse[index].toStringAsFixed(1)} ha',
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${bestSolution!.waterAllocation[index].toStringAsFixed(0)}m³',
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${bestSolution!.fertilizerAllocation[index].toStringAsFixed(0)}kg',
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),

            SizedBox(height: 16),
            if (_optimizationMetrics.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricCard(
                    'Overall Score',
                    '${(bestSolution!.fitness * 100).toStringAsFixed(1)}%',
                    Colors.purple,
                  ),
                  _buildMetricCard(
                    'Total Yield',
                    '${_optimizationMetrics['totalYield']} t',
                    Colors.orange,
                  ),
                  _buildMetricCard(
                    'Profitability',
                    '${((double.tryParse(_optimizationMetrics['profitability'].toString()) ?? 0.0) * 100).toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                  _buildMetricCard(
                    'Sustainability',
                    '${((double.tryParse(_optimizationMetrics['sustainability'].toString()) ?? 0.0) * 100).toStringAsFixed(1)}%',
                    Colors.green,
                  ),
                  _buildMetricCard(
                    'Water Efficiency',
                    '${((double.tryParse(_optimizationMetrics['waterEfficiency'].toString()) ?? 0.0) * 100).toStringAsFixed(1)}%',
                    Colors.cyan,
                  ),
                ],
              ),

            // Recommendations section
            if (_recommendations.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                '💡 Smart Recommendations:',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              ..._recommendations.map(
                (recommendation) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendation,
                          style: GoogleFonts.nunito(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class EcoChromosome {
  List<String> crops;
  List<double> waterAllocation;
  List<double> fertilizerAllocation;
  List<double> landUse;
  List<int> plantingSchedule;
  List<double> pesticidesUse;
  double fitness;

  EcoChromosome({
    required this.crops,
    required this.waterAllocation,
    required this.fertilizerAllocation,
    required this.landUse,
    required this.plantingSchedule,
    required this.pesticidesUse,
    this.fitness = 0.0,
  });

  factory EcoChromosome.copy(EcoChromosome other) {
    return EcoChromosome(
      crops: List<String>.from(other.crops),
      waterAllocation: List<double>.from(other.waterAllocation),
      fertilizerAllocation: List<double>.from(other.fertilizerAllocation),
      landUse: List<double>.from(other.landUse),
      plantingSchedule: List<int>.from(other.plantingSchedule),
      pesticidesUse: List<double>.from(other.pesticidesUse),
      fitness: other.fitness,
    );
  }
}
