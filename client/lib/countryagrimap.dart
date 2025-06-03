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

  @override
  void initState() {
    super.initState();
    fetchCitiesAndCoords();
  }

  Future<void> fetchCitiesAndCoords() async {
    setState(() => loading = true);
    // 1. Get all cities
    final citiesResp = await http.get(
      Uri.parse(
        'http://$ipAddress/cities?country=${Uri.encodeComponent(widget.country)}',
      ),
    );
    if (citiesResp.statusCode != 200) {
      setState(() => loading = false);
      return;
    }
    final cities = List<String>.from(jsonDecode(citiesResp.body)['cities']);
    // 2. For each city, get coordinates (limit to first 20 for demo/performance)
    final List<Map<String, dynamic>> markers = [];
    for (final city in cities.take(20)) {
      final coordsResp = await http.get(
        Uri.parse(
          'http://$ipAddress/city-coords?city=${Uri.encodeComponent(city)}',
        ),
      );
      if (coordsResp.statusCode == 200) {
        final coords = jsonDecode(coordsResp.body);
        markers.add({'name': city, 'lat': coords['lat'], 'lon': coords['lon']});
      }
    }
    setState(() {
      cityMarkers = markers;
      loading = false;
    });
  }

  Future<Map<String, dynamic>?> fetchAgriSuitability(String city) async {
    final resp = await http.get(
      Uri.parse(
        'http://$ipAddress/agri-suitability-city?city=${Uri.encodeComponent(city)}',
      ),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    return null;
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
          loading
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
                                        color: Colors.green,
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
