import 'dart:convert';
import 'package:airwise/citydetaildialog.dart';
import 'package:airwise/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class CountryAgriMapPage extends StatefulWidget {
  final String country;
  const CountryAgriMapPage({super.key, required this.country});
  @override
  State<CountryAgriMapPage> createState() => _CountryAgriMapPageState();
}

class _CountryAgriMapPageState extends State<CountryAgriMapPage> {
  List<Map<String, dynamic>> cityMarkers = [];
  bool loading = true;
  //String progressText = '';
  String? selectedPlant;
  List<String> plantNames = [];
  bool loadingPlants = true;
  bool confirmedPlant = false;

  // Soil selection variables
  String selectedSoilType = "loamy";
  double selectedSoilPH = 6.5;

  // Available soil types
  final List<String> soilTypes = [
    "sandy",
    "loamy",
    "clay",
    "sandy-loam",
    "clay-loam",
    "silt",
    "peaty",
  ];

  @override
  void initState() {
    super.initState();
    fetchPlantNames();
  }

  Future<void> fetchCitiesAndCoordsForPlant(String plant) async {
    setState(() {
      loading = true;
      // progressText = '';
    });
    final resp = await http.get(
      Uri.parse(
        'https://$ipAddress/api/agri-suitability-cities?plant=${Uri.encodeComponent(plant)}'
        '&country=${Uri.encodeComponent(widget.country)}'
        '&soilType=${Uri.encodeComponent(selectedSoilType)}'
        '&soilPH=${selectedSoilPH.toString()}',
      ),
    );

    if (resp.statusCode != 200) {
      setState(() => loading = false);
      return;
    }
    final data = jsonDecode(resp.body);
    // Assume API returns: [{name, lat, lon, suitability: "good"/"bad"}]
    setState(() {
      cityMarkers = List<Map<String, dynamic>>.from(data['cities']);
      loading = false;
      //  progressText = '';
    });
  }

  Future<void> fetchPlantNames() async {
    final resp = await http.get(
      Uri.parse('https://$ipAddress/api/plant-names'),
    );
    if (resp.statusCode == 200) {
      setState(() {
        plantNames = List<String>.from(jsonDecode(resp.body)['plants']);
        loadingPlants = false;
      });
    } else {
      setState(() => loadingPlants = false);
    }
  }

  // Future<void> fetchCitiesAndCoords() async {
  //   setState(() {
  //     loading = true;
  //     progressText = '';
  //   }); // 1. Get all cities
  //   final citiesResp = await http.get(
  //     Uri.parse(
  //       'http://$ipAddress/cities?country=${Uri.encodeComponent(widget.country)}',
  //     ),
  //   );
  //   if (citiesResp.statusCode != 200) {
  //     setState(() => loading = false);
  //     return;
  //   }
  //   final cities = List<String>.from(jsonDecode(citiesResp.body)['cities']);
  //   // 2. For each city, get coordinates (limit to first 20 for demo/performance)
  //   final List<Map<String, dynamic>> markers = [];
  //   int index = 0;
  //   for (final city in cities) {
  //     index++;
  //     setState(() {
  //       progressText = 'Loading $index/${cities.length}';
  //     });
  //     final coordsResp = await http.get(
  //       Uri.parse(
  //         'http://$ipAddress/city-coords?city=${Uri.encodeComponent(city)}',
  //       ),
  //     );
  //     if (coordsResp.statusCode == 200) {
  //       final coords = jsonDecode(coordsResp.body);
  //       markers.add({'name': city, 'lat': coords['lat'], 'lon': coords['lon']});
  //     }
  //   }
  //   setState(() {
  //     cityMarkers = markers;
  //     loading = false;
  //     progressText = '';
  //   });
  // }

  Future<Map<String, dynamic>?> fetchAgriSuitability(String city) async {
    final resp = await http.get(
      Uri.parse(
        'https://$ipAddress/api/agri-suitability-city?city=${Uri.encodeComponent(city)}'
        '&plant=${Uri.encodeComponent(selectedPlant!)}'
        '&soilType=${Uri.encodeComponent(selectedSoilType)}'
        '&soilPH=${selectedSoilPH.toString()}',
      ),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    return null;
  }

  Color _getSuitabilityColor(String suitability) {
    switch (suitability.toLowerCase()) {
      case 'excellent':
        return Colors.green.shade700;
      case 'good':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'challenging':
        return Colors.red.shade600;
      case 'poor':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final countryCenters = {widget.country: LatLng(31.0461, 34.8516)};
    final center = countryCenters[widget.country] ?? LatLng(32.5, 35.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Agri Map: ${widget.country}',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
      ),
      body:
          loadingPlants
              ? Center(child: CircularProgressIndicator())
              : selectedPlant == null || !confirmedPlant
              ? Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Plant Selection
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Plant',
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedPlant,
                                  hint: Text('Choose a plant to analyze'),
                                  isExpanded: true,
                                  underline: SizedBox(),
                                  items:
                                      plantNames.map((plant) {
                                        return DropdownMenuItem(
                                          value: plant,
                                          child: Text(plant),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedPlant = value;
                                      confirmedPlant = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Soil Selection
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Soil Information',
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              SizedBox(height: 10),

                              // Soil Type Selection
                              Text(
                                'Soil Type:',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedSoilType,
                                  isExpanded: true,
                                  underline: SizedBox(),
                                  items:
                                      soilTypes.map((soil) {
                                        return DropdownMenuItem(
                                          value: soil,
                                          child: Text(
                                            soil
                                                .replaceAll('-', ' ')
                                                .toUpperCase(),
                                          ),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedSoilType = value!;
                                    });
                                  },
                                ),
                              ),

                              SizedBox(height: 16),

                              // Soil pH Selection
                              Text(
                                'Soil pH: ${selectedSoilPH.toStringAsFixed(1)}',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Slider(
                                value: selectedSoilPH,
                                min: 4.0,
                                max: 9.0,
                                divisions: 50,
                                activeColor: Colors.green.shade700,
                                inactiveColor: Colors.grey.shade300,
                                onChanged: (value) {
                                  setState(() {
                                    selectedSoilPH = value;
                                  });
                                },
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '4.0 (Acidic)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '7.0 (Neutral)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '9.0 (Alkaline)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Analyze Button
                      ElevatedButton(
                        onPressed:
                            selectedPlant != null
                                ? () {
                                  setState(() {
                                    confirmedPlant = true;
                                  });
                                  fetchCitiesAndCoordsForPlant(selectedPlant!);
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Analyze Agricultural Suitability',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : loading
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.black),
                    SizedBox(height: 16),
                    Text(
                      'Loading map...',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'It take a while to load the map, please wait.',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
              : FlutterMap(
                mapController: MapController(),
                options: MapOptions(initialCenter: center, initialZoom: 7.5),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  ),
                  MarkerLayer(
                    markers:
                        cityMarkers
                            .map(
                              (city) => Marker(
                                width: 80,
                                height: 80,
                                point: LatLng(city['lat'], city['lon']),
                                child: GestureDetector(
                                  onTap: () async {
                                    // Step 1: Show loading dialog
                                    // Step 1: Show custom loading dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder:
                                          (_) => Dialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            backgroundColor: Colors.white,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 24.0,
                                                    horizontal: 20,
                                                  ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(
                                                    color:
                                                        Colors.green.shade700,
                                                    strokeWidth: 4,
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    'Analyzing city suitability...',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                    );

                                    // Step 2: Fetch data
                                    final data = await fetchAgriSuitability(
                                      city['name'],
                                    );

                                    // Step 3: Close loading dialog
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }

                                    // Step 4: Show data dialog if data was fetched
                                    if (data != null && context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (_) => CityDetailDialog(city: data),
                                      );
                                    }
                                  },

                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: _getSuitabilityColor(
                                          city['suitability'],
                                        ),
                                        size: 36,
                                      ),
                                      Container(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          city['name'],
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
    );
  }
}
