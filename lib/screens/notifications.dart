import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Optional: Add 'intl: ^0.19.0' to pubspec.yaml for date formatting

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // 🔹 Define Colors (Matching Home Page)
  static const Color yellow = Color(0xFFFFD31A);
  static const Color whiteBg = Colors.white;
  static const Color darkCardBg = Color(0xFF1A1A1A); // Dark background for cards (like drawer)

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: yellow, // Top background Yellow
      body: Column(
        children: [
          /// 🔹 TOP SECTION (Header)
          SizedBox(
            height: size.height * 0.15, // Compact header
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Notifications",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// 🔹 BOTTOM SECTION (White Container with List)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: whiteBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                child: StreamBuilder<QuerySnapshot>(
                  // 🔹 Fetch data from Firestore 'notifications' collection
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .orderBy('timestamp', descending: true) // Newest first
                      .snapshots(),
                  builder: (context, snapshot) {
                    // 1. Loading State
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }

                    // 2. Error State
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text("Something went wrong loading notifications."),
                      );
                    }

                    // 3. Empty State (No Notifications)
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    // 4. Data Exists - Show List
                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        
                        // Safely get data
                        String title = data['title'] ?? 'No Title';
                        String message = data['message'] ?? 'No Message';
                        Timestamp? timestamp = data['timestamp'];
                        
                        // Format time (requires intl package, or use simple string logic)
                        String timeString = timestamp != null
                            ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: darkCardBg, // Dark card like the drawer
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Icon Row
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, color: yellow, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Message Body
                              Text(
                                message,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              
                              // Timestamp
                              if (timeString.isNotEmpty)
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    timeString,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Widget to show when there are no notifications
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_off_outlined,
            size: 60,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "No Notifications Yet",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "We will notify you when there are updates.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 50), // Spacer
      ],
    );
  }
}