import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:studysync/core/services/geofence_service.dart';
import 'package:studysync/features/dasboard/widgets/dashboard_card.dart';

class StudyZonesScreen extends StatefulWidget {
  const StudyZonesScreen({super.key});

  @override
  State<StudyZonesScreen> createState() => _StudyZonesScreenState();
}

class _StudyZonesScreenState extends State<StudyZonesScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  final firestore = FirebaseFirestore.instance;

  // Add Zone Dialog Controllers
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _enterMsgController = TextEditingController(text: "Time to study! Let's get focused. 📚");
  final _exitMsgController = TextEditingController(text: "Great job focusing! Take a nice break. ☕");
  double _radius = 100.0;

  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _geofenceService.addListener(_onGeofenceUpdate);
  }

  void _onGeofenceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _geofenceService.removeListener(_onGeofenceUpdate);
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _enterMsgController.dispose();
    _exitMsgController.dispose();
    super.dispose();
  }

  Future<void> _captureCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
    });

    try {
      final hasPermission = await _geofenceService.requestLocationPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied. Please grant permission in settings.")),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to capture location: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  void _showAddZoneDialog() {
    _nameController.clear();
    _latController.clear();
    _lngController.clear();
    _radius = 100.0;
    _enterMsgController.text = "Time to study! Let's get focused. 📚";
    _exitMsgController.text = "Great job focusing! Take a nice break. ☕";
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff0f172a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white10),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_location_alt_rounded, color: Color(0xff10b981)),
                  SizedBox(width: 10),
                  Text("Add Study Zone", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _getInputDecoration("Zone Name (e.g. College Library)"),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _getInputDecoration("Latitude"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _getInputDecoration("Longitude"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: _loadingLocation || isCreating
                          ? null
                          : () async {
                              await _captureCurrentLocation();
                              setDialogState(() {});
                            },
                      icon: _loadingLocation
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text("Capture Current GPS", style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Zone Radius: ${_radius.toInt()} meters",
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _radius,
                      min: 50,
                      max: 500,
                      divisions: 9,
                      activeColor: const Color(0xff10b981),
                      inactiveColor: Colors.white10,
                      label: "${_radius.toInt()}m",
                      onChanged: isCreating
                          ? null
                          : (val) {
                              setDialogState(() {
                                _radius = val;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _enterMsgController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _getInputDecoration("Entering Alert Message"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _exitMsgController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _getInputDecoration("Exiting Alert Message"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10b981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isCreating
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          final lat = double.tryParse(_latController.text.trim());
                          final lng = double.tryParse(_lngController.text.trim());
                          final enterMsg = _enterMsgController.text.trim();
                          final exitMsg = _exitMsgController.text.trim();

                          if (name.isEmpty || lat == null || lng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please fill all coordinates and name fields.")),
                            );
                            return;
                          }

                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          setDialogState(() {
                            isCreating = true;
                          });

                          try {
                            await firestore.collection("zones").add({
                              "name": name,
                              "latitude": lat,
                              "longitude": lng,
                              "radius": _radius,
                              "isEnabled": true,
                              "enterMessage": enterMsg,
                              "exitMessage": exitMsg,
                            });
                            navigator.pop();
                          } catch (e) {
                            setDialogState(() {
                              isCreating = false;
                            });
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text("Failed to create zone: $e")),
                            );
                          }
                        },
                  child: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Create Zone", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff10b981)),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zones = _geofenceService.zones;
    final lat = _geofenceService.currentLatitude;
    final lng = _geofenceService.currentLongitude;

    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: Stack(
        children: [
          // Ambient backgrounds
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: const Color(0xff10b981).withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: Colors.blue.withOpacity(0.04),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildTrackingStatusCard(lat, lng),
                _buildSimulationCockpit(zones),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    "CONFIGURED ZONES",
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                Expanded(
                  child: _buildZonesList(zones),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff10b981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _showAddZoneDialog,
        child: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            "Geofenced Study Zones",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStatusCard(double? lat, double? lng) {
    final isSimulated = _geofenceService.isSimulated;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: DashboardCard(
        glowColor: isSimulated ? Colors.pinkAccent : const Color(0xff10b981),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSimulated ? Icons.terminal_rounded : Icons.gps_fixed_rounded,
                color: isSimulated ? Colors.pinkAccent : const Color(0xff10b981),
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSimulated ? "SIMULATED COORDINATES" : "ACTIVE GPS LOCATION",
                      style: TextStyle(
                        color: isSimulated ? Colors.pinkAccent : const Color(0xff10b981),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lat != null && lng != null
                          ? "Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}"
                          : "Resolving GPS Position...",
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (isSimulated)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () {
                    _geofenceService.clearSimulation();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Reverted to real GPS satellite coordinates.")),
                    );
                  },
                  child: const Text("Reset", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationCockpit(List<StudyZone> zones) {
    if (zones.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: DashboardCard(
        glowColor: Colors.purpleAccent,
        bgOpacity: 0.08,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.precision_manufacturing_rounded, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "GEOFENCE COCKPIT SIMULATOR",
                    style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Trigger enter/exit events inside the library or study cafe to verify reminder alerts instantly.",
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: zones.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    final zone = zones[idx];
                    final isInside = _geofenceService.isInsideMap[zone.id] ?? false;

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInside ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                        foregroundColor: isInside ? Colors.redAccent : Colors.greenAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isInside ? Colors.redAccent : Colors.greenAccent, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () {
                        if (isInside) {
                          // Move user safely outside the geofence radius
                          _geofenceService.simulateLocation(
                            zone.latitude + 0.005,
                            zone.longitude + 0.005,
                          );
                        } else {
                          // Move user directly to the center coordinates
                          _geofenceService.simulateLocation(
                            zone.latitude,
                            zone.longitude,
                          );
                        }
                      },
                      child: Text(
                        isInside ? "Leave ${zone.name}" : "Enter ${zone.name}",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZonesList(List<StudyZone> zones) {
    if (zones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text(
              "No Study Zones Configured",
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              "Add locations like the library or study halls.",
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: zones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final zone = zones[idx];
        final isInside = _geofenceService.isInsideMap[zone.id] ?? false;
        final distance = _geofenceService.getDistanceToZone(zone);

        return DashboardCard(
          glowColor: isInside ? Colors.greenAccent : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.name,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Radius: ${zone.radius.toInt()}m | ${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}",
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: zone.isEnabled,
                      activeColor: const Color(0xff10b981),
                      onChanged: (val) async {
                        await firestore.collection("zones").doc(zone.id).update({
                          "isEnabled": val,
                        });
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isInside ? Colors.greenAccent : Colors.white24,
                            shape: BoxShape.circle,
                            boxShadow: isInside
                                ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isInside ? "CURRENTLY INSIDE" : "OUTSIDE RANGE",
                          style: TextStyle(
                            color: isInside ? Colors.greenAccent : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          distance != null
                              ? distance < 1000
                                  ? "${distance.round()}m away"
                                  : "${(distance / 1000).toStringAsFixed(1)}km away"
                              : "Calculating...",
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 14),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () async {
                            await firestore.collection("zones").doc(zone.id).delete();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
