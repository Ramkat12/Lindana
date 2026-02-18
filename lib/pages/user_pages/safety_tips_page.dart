import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SafetyTipsPage extends StatefulWidget {
  final bool showUploadDialog;

  const SafetyTipsPage({super.key, this.showUploadDialog = false});

  @override
  State<SafetyTipsPage> createState() => _SafetyTipsPageState();
}

class _SafetyTipsPageState extends State<SafetyTipsPage> {
  List<Map<String, dynamic>> safetyTips = [];
  List<Map<String, dynamic>> educationalContent = [];
  List<dynamic> purchasedContentIds = [];
  String selectedCategory = 'All';
  String? userId;
  String baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';
  final List<String> categories = [
    'All',
    'Personal Safety',
    'Public Transport',
    'At Home',
    'Street Safety',
    'Travel Safety',
    'Community Warnings',
  ];

  final int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    loadEnv();
    //baseUrl = dotenv.env['BASE_URL'] ?? 'https://b2e5-197-136-185-70.ngrok-free.app';
    fetchUserIdFromToken().then((_) {
      fetchSafetyTips();
      fetchEducationalContent();
      fetchPurchasedContentIds();
      if (widget.showUploadDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAddTipDialog();
        });
      }
    });
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

  Future<void> fetchUserIdFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      try {
        final payload = token.split('.')[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final payloadMap = json.decode(decoded);
        setState(() {
          userId = payloadMap['sub'];
        });
        print('Decoded user ID: $userId');
      } catch (e) {
        print('JWT decode error: $e');
      }
    }
  }

  Future<void> fetchSafetyTips() async {
    final response = await http.get(Uri.parse('$baseUrl/get_tips'));
    if (response.statusCode == 200) {
      setState(() {
        safetyTips = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    } else {
      print("Failed to fetch safety tips: ${response.body}");
    }
  }

  Future<void> fetchEducationalContent() async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_educational_content'),
    );
    if (response.statusCode == 200) {
      setState(() {
        educationalContent = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );
      });
    } else {
      print("Failed to fetch educational content: ${response.body}");
    }
  }

  Future<void> fetchPurchasedContentIds() async {
    if (userId == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/user_purchases/$userId'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        purchasedContentIds = List.from(data['purchased_ids']);
      });
    } else {
      print("Failed to fetch purchases: ${response.body}");
    }
  }

  void _showAddTipDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String? selectedCategoryDialog;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add a Safety Tip'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .where((c) => c != 'All')
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedCategoryDialog = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FABCB),
              ),
              onPressed: () async {
                if (selectedCategoryDialog != null) {
                  await uploadTip(
                    titleController.text,
                    contentController.text,
                    selectedCategoryDialog!,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> uploadTip(String title, String content, String category) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to submit a tip.")),
      );
      return;
    }

    final tipData = {
      "title": title,
      "content": content,
      "category": category,
      "submitted_by": userId,
      "submitted_by_role": "user",
      "status": "pending",
    };

    final response = await http.post(
      Uri.parse('$baseUrl/upload_tip'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(tipData),
    );

    if (response.statusCode == 200) {
      fetchSafetyTips();
    } else {
      print("Failed to upload tip: ${response.body}");
    }
  }

  void _showBottomSheetContent(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                item['title'] ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(item['content'] ?? '', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              if (item.containsKey('category'))
                Text(
                  'Category: ${item['category']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (item.containsKey('price'))
                Text(
                  'Price: KES ${item['price']}',
                  style: const TextStyle(fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle purchase of educational content using PayPal
  // New payment flow using WebView
  Future<void> _startPaymentFlow(Map<String, dynamic> content) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must be logged in to purchase content."),
        ),
      );
      return;
    }

    Future<void> capturePayment(String orderId, dynamic contentId) async {
      final response = await http.post(
        Uri.parse('$baseUrl/capture-order/$orderId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": userId, "content_id": contentId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Payment successful!")));
        await fetchPurchasedContentIds();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment failed to capture.")),
        );
      }
    }

    // Create order by calling your backend's /create-order endpoint
    final createOrderResponse = await http.post(
      Uri.parse('$baseUrl/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "user_id": userId,
        "content_id": content['id'],
        "content_title": content['title'],
        "amount": content['price'].toString(),
        "currency": "USD",
      }),
    );

    if (createOrderResponse.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to create PayPal order.")),
      );
      return;
    }

    final data = jsonDecode(createOrderResponse.body);
    final orderId = data["order_id"];
    final approvalUrl = data["approval_url"];

    // Open a new page with WebView to load the approval URL
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Complete Payment")),
          body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadRequest(Uri.parse(approvalUrl))
              ..setNavigationDelegate(
                NavigationDelegate(
                  onNavigationRequest: (nav) async {
                    // Detect when the URL indicates payment success
                    if (nav.url.contains("payment-success")) {
                      await capturePayment(orderId, content['id']);
                      Navigator.pop(context, true);
                      return NavigationDecision.prevent;
                    }
                    // Optionally handle cancel URL similarly
                    return NavigationDecision.navigate;
                  },
                ),
              ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTips = safetyTips
        .where(
          (tip) =>
              tip['status'] != 'deleted' &&
              (selectedCategory == 'All' ||
                  (tip['category']?.toString() == selectedCategory)),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Learning')),
      body: ListView(
        children: [
          // Section for Educational Content with Paid Access
          if (educationalContent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Educational Resources (Paid)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: educationalContent.length,
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemBuilder: (context, index) {
                        final content = educationalContent[index];
                        final isUnlocked = purchasedContentIds.contains(
                          content['id'],
                        );

                        return Container(
                          width: 250,
                          margin: const EdgeInsets.only(right: 12),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            child: InkWell(
                              onTap: () async {
                                if (isUnlocked) {
                                  _showBottomSheetContent(content);
                                } else {
                                  final shouldPay = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Unlock Content"),
                                      content: Text(
                                        "This item costs KES ${content['price']}. Would you like to proceed?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("Buy"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldPay == true) {
                                    _startPaymentFlow(content);
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      content['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text("KES ${content['price']}"),
                                    const Spacer(),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: isUnlocked
                                          ? const Icon(
                                              Icons.lock_open,
                                              color: Colors.green,
                                            )
                                          : ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color(
                                                  0xFF4FABCB,
                                                ),
                                              ),
                                              onPressed: () async {
                                                final shouldPay =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      builder: (_) => AlertDialog(
                                                        title: const Text(
                                                          "Unlock Content",
                                                        ),
                                                        content: Text(
                                                          "This item costs KES ${content['price']}. Would you like to proceed?",
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              "Cancel",
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              "Buy",
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                if (shouldPay == true) {
                                                  _startPaymentFlow(content);
                                                }
                                              },
                                              child: const Text("Unlock"),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Section for Community Safety Tips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Community Safety Tips',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((category) {
                final isSelected = category == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => selectedCategory = category),
                    selectedColor: const Color(0xFF4FABCB),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Display filtered safety tips
          ...filteredTips.map((tip) {
            final isFlagged = tip['status'] == 'false';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              shape: RoundedRectangleBorder(
                side: isFlagged
                    ? const BorderSide(color: Colors.red, width: 2)
                    : BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              color: isFlagged ? Colors.red.shade50 : null,
              child: ListTile(
                title: Text(
                  tip['title'],
                  style: TextStyle(
                    color: isFlagged ? Colors.red.shade800 : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category: ${tip['category']}'),
                    if (isFlagged)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          '⚠️ This tip has been flagged as false by moderators.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () => _showBottomSheetContent(tip),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton(
              onPressed: _showAddTipDialog,
              backgroundColor: const Color(0xFF4FABCB),
              child: const Icon(Icons.add),
            ),
      // bottomNavigationBar: CustomBottomNavigationBar(currentIndex: _selectedIndex),
    );
  }
}
