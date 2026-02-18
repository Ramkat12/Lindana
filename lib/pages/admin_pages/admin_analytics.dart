import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/components/custom_admin.navbar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:is_project_1/pages/admin_pages/admin_homepage.dart';
/*
class UserDistribution {
  final int totalUsers;

  UserDistribution({
    required this.totalUsers,
    required this.legalAidProviders,
    required this.admins,
  });

  factory UserDistribution.fromJson(Map<String, dynamic> json) {
    return UserDistribution(
      totalUsers: json['total_users'] ?? 0,
      legalAidProviders: json['legal_aid_providers'] ?? 0,
      admins: json['admins'] ?? 0,
    );
  }
}*/

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

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});
  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  Map<String, dynamic> analytics = {};
  bool isLoading = true;
  String? error;

  //UserDistribution? userDistribution;
  DangerZonesData? dangerZonesData;

  String baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';

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
      await Future.wait([_fetchDangerZonesData()]);

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

  /*Future<void> _fetchUserDistribution() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/user-distribution'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        userDistribution = UserDistribution.fromJson(data);
      } else {
        throw Exception(
          'Failed to fetch user distribution: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching user distribution: $e');
      // Use mock data as fallback
      userDistribution = UserDistribution(
        totalUsers: 45,
        legalAidProviders: 35,
        admins: 20,
      );
    }
  }*/

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
        dangerZonesData = DangerZonesData.fromJson(data);
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Handle case when there's no previous page
              // You can navigate to a specific page or show a message
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AdminHomepage()),
                (route) => false,
              ); // Replace with your home route
            }
          },
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
                    // Usage Metrics Card
                    _buildUsageMetricsCard(),
                    const SizedBox(height: 20),

                    // Revenue Generated Card
                    _buildRevenueCard(),
                    const SizedBox(height: 20),

                    // Frequent Danger Zones Card
                    if (dangerZonesData != null) _buildDangerZonesCard(),

                    const SizedBox(height: 20),
                    _buildSafetyTipsCard(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const CustomAdminNavigationBar(currentIndex: 2),
    );
  }

  Widget _buildUsageMetricsCard() {
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Usage Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'User Distribution',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: [
                    PieChartSectionData(
                      color: const Color.fromARGB(255, 244, 6, 85),
                      value: (analytics['providers'] ?? 0).toDouble(),
                      title: '${analytics['providers'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.lightBlue,
                      value: (analytics['users'] ?? 0).toDouble(),
                      title: '${analytics['users'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: const Color.fromARGB(255, 243, 174, 255),
                      value: (analytics['admins'] ?? 0).toDouble(),
                      title: '${analytics['admins'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  'Legal Aid Providers',
                  const Color.fromARGB(255, 244, 6, 85),
                ),
                _buildLegendItem('Users', Colors.lightBlue),
                _buildLegendItem(
                  'Admin',
                  const Color.fromARGB(255, 243, 174, 255),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    final totalRevenue = analytics['total_revenue'] ?? 0;
    final topContent = analytics['top_content'] ?? [];
    final recent = analytics['recent_purchases'] ?? [];

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Revenue Overview',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              "💰 Total Revenue Generated",
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            Text(
              "KSh $totalRevenue",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
            const Divider(height: 32),

            // Top Content in pill cards
            if (topContent.isNotEmpty) ...[
              const Text(
                "🏆 Top Purchased Content",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Column(
                children: topContent.map<Widget>((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['title'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          "KSh ${item['total']}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 32),
            ],

            // Recent Purchases
            const Text(
              "🕒 Latest Purchases",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                itemCount: recent.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final tx = recent[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 18,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx['title'],
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                tx['date'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "KSh ${tx['amount']}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildSafetyTipsCard() {
    final total = analytics['tips_total'] ?? 0;
    final verified = analytics['tips_verified'] ?? 0;
    final pending = analytics['tips_pending'] ?? 0;
    final submitters = analytics['tips_submitters'] ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.orangeAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Safety Tips',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('Total', total, Colors.blue),
                _buildStat('Verified', verified, Colors.green),
                _buildStat('Pending', pending, Colors.amber.shade800),
                _buildStat('Submitters', submitters, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
