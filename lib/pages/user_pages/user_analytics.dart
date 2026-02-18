import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/components/custom_bootom_navbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:geocoding/geocoding.dart';

// Location Analytics Models
class LocationAnalytics {
  final int totalUsers;
  final int activeLocationUsers;
  final int inactiveLocationUsers;
  final double locationSharingRate;
  final List<TopLocation> topLocations;
  final List<RecentActivity> recentActivities;
  final List<UserLocationStats> userLocationStats;

  LocationAnalytics({
    required this.totalUsers,
    required this.activeLocationUsers,
    required this.inactiveLocationUsers,
    required this.locationSharingRate,
    required this.topLocations,
    required this.recentActivities,
    required this.userLocationStats,
  });

  factory LocationAnalytics.fromJson(Map<String, dynamic> json) {
    return LocationAnalytics(
      totalUsers: json['total_users'] ?? 0,
      activeLocationUsers: json['active_location_users'] ?? 0,
      inactiveLocationUsers: json['inactive_location_users'] ?? 0,
      locationSharingRate: (json['location_sharing_rate'] ?? 0.0).toDouble(),
      topLocations: (json['top_locations'] as List? ?? [])
          .map((item) => TopLocation.fromJson(item))
          .toList(),
      recentActivities: (json['recent_activities'] as List? ?? [])
          .map((item) => RecentActivity.fromJson(item))
          .toList(),
      userLocationStats: (json['user_location_stats'] as List? ?? [])
          .map((item) => UserLocationStats.fromJson(item))
          .toList(),
    );
  }
}

class TopLocation {
  final double latitude;
  final double longitude;
  final int visitCount;

  TopLocation({
    required this.latitude,
    required this.longitude,
    required this.visitCount,
  });

  factory TopLocation.fromJson(Map<String, dynamic> json) {
    return TopLocation(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      visitCount: json['visit_count'] ?? 0,
    );
  }
}

class RecentActivity {
  final String userEmail;
  final double latitude;
  final double longitude;
  final String activityName;
  final DateTime recordedAt;

  RecentActivity({
    required this.userEmail,
    required this.latitude,
    required this.longitude,
    required this.activityName,
    required this.recordedAt,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      userEmail: json['user_email'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      activityName: json['activity_name'] ?? '',
      recordedAt: DateTime.parse(json['recorded_at']),
    );
  }
}

class UserLocationStats {
  final String userId;
  final int totalLogs;
  final int uniqueLocations;
  final DateTime lastRecorded;
  final DateTime firstRecorded;

  UserLocationStats({
    required this.userId,
    required this.totalLogs,
    required this.uniqueLocations,
    required this.lastRecorded,
    required this.firstRecorded,
  });

  factory UserLocationStats.fromJson(Map<String, dynamic> json) {
    return UserLocationStats(
      userId: json['user_id'] ?? '',
      totalLogs: json['total_logs'] ?? 0,
      uniqueLocations: json['unique_locations'] ?? 0,
      lastRecorded: DateTime.parse(json['last_recorded']),
      firstRecorded: DateTime.parse(json['first_recorded']),
    );
  }
}

class DangerZoneDataPoint {
  final String location;
  final int incidentCount;

  DangerZoneDataPoint({required this.location, required this.incidentCount});

  factory DangerZoneDataPoint.fromJson(Map<String, dynamic> json) {
    return DangerZoneDataPoint(
      location: json['location_name'] ?? '',
      incidentCount: json['reported_count'] ?? 0,
    );
  }
}

class DangerZonesData {
  final List<DangerZoneDataPoint> data;
  final int totalIncidents;

  DangerZonesData({required this.data, required this.totalIncidents});

  factory DangerZonesData.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List? ?? [];
    List<DangerZoneDataPoint> dataPoints = list
        .map((i) => DangerZoneDataPoint.fromJson(i))
        .toList();

    return DangerZonesData(
      data: dataPoints,
      totalIncidents: json['total_incidents'] ?? 0,
    );
  }
}

class UserAnalytics extends StatefulWidget {
  const UserAnalytics({super.key});
  @override
  State<UserAnalytics> createState() => _UserAnalyticsState();
}

class _UserAnalyticsState extends State<UserAnalytics> {
  Map<String, dynamic> analytics = {};
  bool isLoading = true;
  String? error;

  DangerZonesData? dangerZonesData;
  LocationAnalytics? locationAnalytics;

  String baseUrl = 'https://f77c2776a833.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadEnv();
    await _loadAnalyticsData();
    await _fetchAnalytics();
  }

  Future<void> _loadEnv() async {
    try {
      await dotenv.load(fileName: ".env");
      setState(() {
        baseUrl = dotenv.env['API_BASE_URL'] ?? baseUrl;
      });
    } catch (e) {
      print('Error loading .env file: $e');
    }
  }

  Future<void> _fetchAnalytics() async {
    final String baseUrl = dotenv.env['BASE_URL']!;
    final response = await http.get(Uri.parse('$baseUrl/analytics/overview'));
    if (response.statusCode == 200) {
      setState(() {
        analytics = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load analytics")));
    }
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Fetch all analytics data
      await Future.wait([_fetchDangerZonesData(), _fetchLocationAnalytics()]);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Failed to load analytics data: ${e.toString()}';
      });
    }
  }

  Future<String> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Create a readable address
        String locationName = '';
        if (place.name != null && place.name!.isNotEmpty) {
          locationName = place.name!;
        } else if (place.street != null && place.street!.isNotEmpty) {
          locationName = place.street!;
        }

        if (place.locality != null && place.locality!.isNotEmpty) {
          locationName += locationName.isEmpty
              ? place.locality!
              : ', ${place.locality!}';
        }

        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          locationName += locationName.isEmpty
              ? place.administrativeArea!
              : ', ${place.administrativeArea!}';
        }

        return locationName.isEmpty ? 'Unknown Location' : locationName;
      }
    } catch (e) {
      print('Error getting location name: $e');
    }
    return 'Unknown Location';
  }

  Future<void> _fetchLocationAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/recent-locations'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          locationAnalytics = LocationAnalytics.fromJson(data);
        });
      } else {
        throw Exception(
          'Failed to fetch location analytics: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching location analytics: $e');
      // Use mock data as fallback
      setState(() {
        locationAnalytics = LocationAnalytics(
          totalUsers: 45,
          activeLocationUsers: 28,
          inactiveLocationUsers: 17,
          locationSharingRate: 62.2,
          topLocations: [],
          recentActivities: [],
          userLocationStats: [],
        );
      });
    }
  }

  Future<void> _fetchDangerZonesData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/danger-zones'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          dangerZonesData = DangerZonesData.fromJson(data);
        });
      } else {
        throw Exception(
          'Failed to fetch danger zones data: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching danger zones data: $e');
      // Use mock data as fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics Dashboard',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Monitor app usage and performance metrics',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadAnalyticsData,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAnalyticsData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAnalyticsData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Analytics Card
                    if (locationAnalytics != null)
                      _buildLocationAnalyticsCard(),
                    const SizedBox(height: 20),

                    // Frequent Danger Zones Card
                    if (dangerZonesData != null) _buildDangerZonesCard(),
                  ],
                ),
              ),
            ),
      // Use the regular user bottom navigation bar so that
      // users never see admin navigation while viewing analytics.
      // We keep the "Profile" tab highlighted since analytics
      // is accessed from the profile page.
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 3),
    );
  }

  Widget _buildLocationAnalyticsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Location Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location sharing overview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLocationStat(
                        'Active',
                        locationAnalytics!.activeLocationUsers,
                        Colors.green,
                        Icons.location_on,
                      ),
                      _buildLocationStat(
                        'Inactive',
                        locationAnalytics!.inactiveLocationUsers,
                        Colors.orange,
                        Icons.location_off,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade100, Colors.green.shade50],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${locationAnalytics!.locationSharingRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text(
                          'Location Sharing Rate',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recent activities section with location names
            if (locationAnalytics!.recentActivities.isNotEmpty) ...[
              const Text(
                'Recent Location Activities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: locationAnalytics!.recentActivities.length,
                  itemBuilder: (context, index) {
                    final activity = locationAnalytics!.recentActivities[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  activity.userEmail,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTimeAgo(activity.recordedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Location name with coordinates
                          FutureBuilder<String>(
                            future: _getLocationName(
                              activity.latitude,
                              activity.longitude,
                            ),
                            builder: (context, snapshot) {
                              return Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          snapshot.data ??
                                              'Loading location...',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${activity.latitude.toStringAsFixed(4)}, ${activity.longitude.toStringAsFixed(4)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.directions_walk,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    activity.activityName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No recent location activities found. Users may not have enabled location sharing.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Top locations section with location names
            if (locationAnalytics!.topLocations.isNotEmpty) ...[
              const Text(
                'Most Visited Locations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...locationAnalytics!.topLocations.take(5).map((location) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<String>(
                          future: _getLocationName(
                            location.latitude,
                            location.longitude,
                          ),
                          builder: (context, snapshot) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.data ?? 'Loading location...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                Text(
                                  '${location.visitCount} visits',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStat(
    String label,
    int value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildDangerZonesCard() {
    // Get top 10 danger zones sorted by incident count
    final sortedData = List.from(dangerZonesData!.data)
      ..sort((a, b) => b.incidentCount.compareTo(a.incidentCount));
    final top10Data = sortedData.take(10).toList();

    final maxIncidents = top10Data.isNotEmpty
        ? top10Data.first.incidentCount.toDouble()
        : 0.0;

    // Calculate chart width based on number of items (minimum width per bar)
    final chartWidth = (top10Data.length * 80.0).clamp(300.0, double.infinity);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Top 10 Frequent Danger Zones',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Total: ${dangerZonesData!.totalIncidents}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Top incident reports by location (showing highest 10)',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Scrollable chart container
            SizedBox(
              height: 350, // Increased height to accommodate rotated labels
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: 350,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceEvenly,
                      maxY:
                          maxIncidents +
                          (maxIncidents * 0.15), // Add 15% padding to top
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex < top10Data.length) {
                              return BarTooltipItem(
                                '${top10Data[groupIndex].location}\n${rod.toY.toInt()} incidents',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize:
                                80, // Increased space for rotated labels
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < top10Data.length) {
                                final location =
                                    top10Data[value.toInt()].location;
                                // Truncate long location names
                                final displayText = location.length > 15
                                    ? '${location.substring(0, 12)}...'
                                    : location;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Transform.rotate(
                                    angle:
                                        -0.8, // Slightly more rotation for better readability
                                    child: Text(
                                      displayText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxIncidents > 50 ? 10 : 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300]!,
                            strokeWidth: 0.8,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: top10Data.asMap().entries.map((entry) {
                        // Color gradient based on incident count
                        final intensity =
                            entry.value.incidentCount / maxIncidents;
                        final barColor = Color.lerp(
                          Colors.red[300]!,
                          Colors.red[800]!,
                          intensity,
                        )!;

                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.incidentCount.toDouble(),
                              color: barColor,
                              width:
                                  35, // Slightly wider bars for better visibility
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                              // Add a subtle gradient effect
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [barColor.withOpacity(0.8), barColor],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            // Add a small indicator showing this is scrollable
            if (top10Data.length >
                3) // Only show if there are enough items to scroll
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_right, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      'Swipe to view all zones',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
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

  Color _getBarColor(int incidentCount) {
    if (incidentCount >= 20) return Colors.red;
    if (incidentCount >= 10) return Colors.orange;
    if (incidentCount >= 5) return Colors.yellow[700]!;
    return Colors.green;
  }

  Color _getZoneColor(int incidentCount) {
    if (incidentCount >= 20) return Colors.red;
    if (incidentCount >= 10) return Colors.orange;
    if (incidentCount >= 5) return Colors.amber;
    return Colors.green;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
