import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ModerateSafetyTipsPage extends StatefulWidget {
  const ModerateSafetyTipsPage({super.key});

  @override
  State<ModerateSafetyTipsPage> createState() => _ModerateSafetyTipsPageState();
}

class _ModerateSafetyTipsPageState extends State<ModerateSafetyTipsPage> {
  List<dynamic> safetyTips = [];
  String selectedStatus = 'pending';
  String baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    loadEnv();
    _loadSafetyTips();
  }

  Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: ".env");
      setState(() {
        baseUrl = dotenv.env['API_BASE_URL'] ?? baseUrl;
      });
    } catch (e) {
      print('Error loading .env file: $e');
    }
  }

  Future<void> _loadSafetyTips() async {
    final response = await http.get(Uri.parse('$baseUrl/safety_tips'));
    if (response.statusCode == 200) {
      setState(() {
        safetyTips = jsonDecode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch safety tips")),
      );
    }
  }

  Future<void> _updateTipStatus(int tipId, String action) async {
    final response = await http.put(
      Uri.parse('$baseUrl/safety_tips/$tipId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': action}),
    );
    if (response.statusCode == 200) {
      _loadSafetyTips();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tip updated: $action')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to update tip")));
    }
  }

  Future<void> _permanentlyDeleteTip(int tipId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/safety_tips/$tipId'),
    );
    if (response.statusCode == 200) {
      _loadSafetyTips();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tip permanently deleted.")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to permanently delete tip.")),
      );
    }
  }

  void _confirmPermanentDelete(BuildContext context, int tipId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permanently Delete"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _permanentlyDeleteTip(tipId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );
  }

  void _showConfirmDelete(BuildContext context, int tipId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text("Are you sure you want to delete this safety tip?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateTipStatus(tipId, 'deleted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredList() {
    final filtered = safetyTips
        .where((tip) => tip['status'] == selectedStatus)
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildTipCard(filtered[index]),
    );
  }

  Widget _buildTipCard(dynamic tip) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          tip['title'] ?? '(No Title)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Text(tip['content'] ?? '(No Content)'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'deleted') {
                    _showConfirmDelete(context, tip['id']);
                  } else if (value == 'permanently_delete') {
                    _confirmPermanentDelete(context, tip['id']);
                  } else {
                    _updateTipStatus(tip['id'], value);
                  }
                },
                itemBuilder: (context) => _buildStatusOptions(tip['status']),
                icon: const Icon(Icons.more_vert, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildStatusOptions(String currentStatus) {
    final Map<String, List<String>> transitions = {
      'pending': ['verified', 'false', 'deleted'],
      'verified': ['false', 'pending', 'deleted'],
      'false': ['verified', 'pending'],
      'deleted': ['pending'],
    };

    final entries =
        transitions[currentStatus]?.map((status) {
          return PopupMenuItem(
            value: status,
            child: Text(
              "Mark as ${status[0].toUpperCase()}${status.substring(1)}",
            ),
          );
        }).toList() ??
        [];

    if (currentStatus == 'deleted') {
      entries.add(
        const PopupMenuItem(
          value: 'permanently_delete',
          child: Text(
            "Permanently Delete",
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderate Safety Tips'),
        backgroundColor: const Color(0xFF4FABCB),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              children: ['pending', 'verified', 'false', 'deleted'].map((
                status,
              ) {
                return ElevatedButton(
                  onPressed: () {
                    setState(() => selectedStatus = status);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedStatus == status
                        ? const Color(0xFF4FABCB)
                        : const Color.fromARGB(255, 224, 224, 224),
                  ),
                  child: Text(status[0].toUpperCase() + status.substring(1)),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: safetyTips.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildFilteredList(),
          ),
        ],
      ),
    );
  }
}
