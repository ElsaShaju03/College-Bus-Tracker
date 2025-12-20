import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🔹 Import this for kIsWeb check
import 'package:geolocator/geolocator.dart'; 
import '../main.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  // Check current permission status
  Future<void> _checkLocationStatus() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (mounted) {
        setState(() {
          _isLocationEnabled = isServiceEnabled && 
              (permission == LocationPermission.always || permission == LocationPermission.whileInUse);
        });
      }
    } catch (e) {
      debugPrint("Error checking location status: $e");
    }
  }

  // 🔹 FIXED: Handle Location Switch (Web vs Mobile)
  Future<void> _toggleLocation(bool value) async {
    // 1. Handle Web Platform
    if (kIsWeb) {
      if (value) {
        // On Web, we can only request permission, not open settings
        LocationPermission permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please enable Location in your browser settings.")),
            );
          }
        }
      } else {
        // We cannot programmatically disable location on Web
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("To disable location, please reset permissions in your browser address bar.")),
        );
      }
      _checkLocationStatus();
      return; 
    }

    // 2. Handle Mobile (Android/iOS)
    // On mobile, we open the OS settings
    await Geolocator.openAppSettings();
    
    // Refresh status after returning (user might have changed it)
    _checkLocationStatus();
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Determine Colors based on Theme
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final Color headerColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFD31A);
    final Color bottomSheetColor = Theme.of(context).cardColor;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: headerColor,
      appBar: AppBar(
        title: Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // 🔹 BOTTOM SECTION (Rounded Sheet)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: bottomSheetColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ListView(
                  children: [
                    
                    // 1. DAY/NIGHT MODE
                    _buildSectionHeader("Appearance", isDarkMode),
                    Container(
                      decoration: _boxDecoration(isDarkMode),
                      child: SwitchListTile(
                        title: Text("Dark Mode", style: _textStyle(isDarkMode)),
                        secondary: Icon(
                          isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: const Color(0xFFFFD31A),
                        ),
                        value: isDarkMode,
                        activeColor: const Color(0xFFFFD31A),
                        onChanged: (bool value) {
                          // 🔹 Toggle Global Theme
                          themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. LOCATION PERMISSIONS
                    _buildSectionHeader("Permissions", isDarkMode),
                    Container(
                      decoration: _boxDecoration(isDarkMode),
                      child: SwitchListTile(
                        title: Text("Location Access", style: _textStyle(isDarkMode)),
                        subtitle: Text(
                          _isLocationEnabled ? "Enabled" : "Disabled",
                          style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54, fontSize: 12),
                        ),
                        secondary: Icon(Icons.location_on, color: _isLocationEnabled ? Colors.green : Colors.grey),
                        value: _isLocationEnabled,
                        activeColor: const Color(0xFFFFD31A),
                        onChanged: (val) => _toggleLocation(val),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. PRIVACY & SECURITY
                    _buildSectionHeader("Legal", isDarkMode),
                    Container(
                      decoration: _boxDecoration(isDarkMode),
                      child: ListTile(
                        leading: const Icon(Icons.security, color: Colors.blueAccent),
                        title: Text("Privacy & Security", style: _textStyle(isDarkMode)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDarkMode ? Colors.white70 : Colors.black45),
                        onTap: () {
                          // Show Privacy Dialog or Navigate
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Privacy & Security"),
                              content: const Text("This app collects location data to track buses. Your data is secure and not shared with third parties."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Helper Styles
  TextStyle _textStyle(bool isDark) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey : Colors.black54,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100, // Inner card color
      borderRadius: BorderRadius.circular(15),
    );
  }
}