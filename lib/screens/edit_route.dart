import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditRouteScreen extends StatefulWidget {
  final String busId;
  final String busNumber;

  const EditRouteScreen({
    super.key,
    required this.busId,
    required this.busNumber,
  });

  @override
  State<EditRouteScreen> createState() => _EditRouteScreenState();
}

class _EditRouteScreenState extends State<EditRouteScreen> {
  // Controllers for the input form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  // Colors based on your theme
  static const Color yellow = Color(0xFFFFD31A);
  static const Color darkBg = Color(0xFF1A1A1A);

  // 🔹 FUNCTION: Add a stop to Firebase
  Future<void> _addStopToFirebase() async {
    if (_nameController.text.isEmpty ||
        _timeController.text.isEmpty ||
        _latController.text.isEmpty ||
        _lngController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      // 1. Create the stop data object
      final newStop = {
        "stopName": _nameController.text.trim(),
        "time": _timeController.text.trim(),
        "lat": double.parse(_latController.text.trim()),
        "lng": double.parse(_lngController.text.trim()),
      };

      // 2. Send to Firebase (ArrayUnion adds it to the existing list)
      await FirebaseFirestore.instance
          .collection('bus_schedules')
          .doc(widget.busId)
          .update({
        "stops": FieldValue.arrayUnion([newStop])
      });

      // 3. Clear form and close dialog
      _nameController.clear();
      _timeController.clear();
      _latController.clear();
      _lngController.clear();
      if (mounted) Navigator.pop(context); // Close the bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Stop added successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding stop: $e")),
      );
    }
  }

  // 🔹 FUNCTION: Delete a stop from Firebase
  Future<void> _deleteStop(Map<String, dynamic> stopData) async {
    try {
      await FirebaseFirestore.instance
          .collection('bus_schedules')
          .doc(widget.busId)
          .update({
        "stops": FieldValue.arrayRemove([stopData])
      });
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  // 🔹 HELPER: Time Picker
  Future<void> _selectTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  // 🔹 UI: Bottom Sheet Form
  void _showAddStopModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows keyboard to push sheet up
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add New Stop",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Stop Name",
                  hintText: "e.g., Central Station",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _timeController,
                readOnly: true,
                onTap: _selectTime,
                decoration: const InputDecoration(
                  labelText: "Arrival Time",
                  hintText: "Tap to select time",
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Latitude",
                        hintText: "e.g. 8.5241",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Longitude",
                        hintText: "e.g. 76.9366",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addStopToFirebase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("SAVE STOP", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manage Route", style: TextStyle(fontSize: 16)),
            Text(widget.busNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: yellow,
        foregroundColor: Colors.black,
      ),
      
      // Floating Button to Open Form
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStopModal,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add_location_alt, color: yellow),
        label: const Text("Add Stop", style: TextStyle(color: Colors.white)),
      ),

      // List of Existing Stops
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bus_schedules')
            .doc(widget.busId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Bus not found"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List stops = data['stops'] ?? [];

          if (stops.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No stops added yet.", style: TextStyle(color: Colors.grey)),
                  Text("Click 'Add Stop' to begin.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Space for FAB
            itemCount: stops.length,
            itemBuilder: (context, index) {
              var stop = stops[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: darkBg,
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(stop['stopName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${stop['time']}  •  Lat: ${stop['lat']}, Lng: ${stop['lng']}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteStop(stop),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}