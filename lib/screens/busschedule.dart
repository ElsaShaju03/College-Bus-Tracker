import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mapscreen.dart'; 
import 'edit_route.dart'; // ✅ IMPORTANT: Ensure this import exists

class BusScheduleScreen extends StatelessWidget {
  const BusScheduleScreen({super.key});

  static const Color yellow = Color(0xFFFFD31A);
  static const Color whiteBg = Colors.white;
  static const Color cardColorLight = Color(0xFF8E9991); 
  static const Color cardColorDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color topSectionColor = isDarkMode ? Colors.black : yellow;
    final Color bottomSheetColor = isDarkMode ? const Color(0xFF121212) : whiteBg;
    final Color currentCardColor = isDarkMode ? cardColorDark : cardColorLight;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color cardTextColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: topSectionColor,
      body: Column(
        children: [
          /// HEADER
          SizedBox(
            height: size.height * 0.15,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    Text("Bus Schedule", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          /// LIST CONTAINER
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: bottomSheetColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('bus_schedules').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: textColor));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No buses yet."));

                    final buses = snapshot.data!.docs;

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: buses.length,
                      itemBuilder: (context, index) {
                        var doc = buses[index]; 
                        var data = doc.data() as Map<String, dynamic>;

                        return GestureDetector(
                          // 🔹 1. TAP CARD -> GO TO MAP (Student View)
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapScreen(routeData: data),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: currentCardColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 50, width: 50,
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                                  child: const Icon(Icons.directions_bus, color: Colors.black, size: 28),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['busNumber'] ?? "Bus No.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cardTextColor)),
                                      Text(data['routeTitle'] ?? "Route Name", style: TextStyle(fontSize: 14, color: cardTextColor.withOpacity(0.8))),
                                    ],
                                  ),
                                ),
                                
                                // 🔹 2. EDIT BUTTON -> GO TO EDIT SCREEN (Admin View)
                                // This is the crucial part that links to your new manual entry page
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditRouteScreen(
                                          busId: doc.id, 
                                          busNumber: data['busNumber'] ?? "Bus"
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
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
}