import 'package:flutter/material.dart';
import 'package:is_project_1/pages/profile_page.dart';

class CustomBlankNavigationBar extends StatelessWidget {
  final dynamic currentIndex;

  const CustomBlankNavigationBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (currentIndex == index) {
      return; // Don't navigate if already on the same page
    }

    // Navigate to the appropriate page based on index
    switch (index) {
      case 0:
        // Navigate to Profile
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
          (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF4FABCB),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      currentIndex: currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
