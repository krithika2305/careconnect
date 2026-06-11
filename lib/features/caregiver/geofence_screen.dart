import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class GeofenceScreen extends ConsumerStatefulWidget {
  final String patientId;

  const GeofenceScreen({super.key, required this.patientId});

  @override
  ConsumerState<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends ConsumerState<GeofenceScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGeofence();
  }

  Future<void> _loadGeofence() async {
    final client = ref.read(supabaseClientProvider);
    final data = await client.from('geofences').select().eq('patient_id', widget.patientId).maybeSingle();
    
    if (data != null && mounted) {
      setState(() {
        _latController.text = data['latitude'].toString();
        _lngController.text = data['longitude'].toString();
        _radiusController.text = data['radius_meters'].toString();
        _isActive = data['is_active'] ?? true;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGeofence() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      
      final lat = double.tryParse(_latController.text) ?? 0.0;
      final lng = double.tryParse(_lngController.text) ?? 0.0;
      final radius = double.tryParse(_radiusController.text) ?? 50.0;

      await client.from('geofences').upsert({
        'patient_id': widget.patientId,
        'caregiver_id': client.auth.currentUser!.id,
        'latitude': lat,
        'longitude': lng,
        'radius_meters': radius,
        'is_active': _isActive,
      });

      ref.invalidate(geofenceProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Safe zone saved successfully!'),
          backgroundColor: MedicalTheme.accentGreen,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: MedicalTheme.accentCoral,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    final radius = double.tryParse(_radiusController.text);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Safe Zone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Wandering Prevention",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: MedicalTheme.darkSlate),
            ),
            const SizedBox(height: 8),
            const Text(
              "Define a safe zone (geofence) for the patient. An alert will trigger if they leave this area.",
              style: TextStyle(color: MedicalTheme.lightSlate),
            ),
            const SizedBox(height: 24),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Coordinates',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.location_on),
                        hintText: 'e.g., 13.0827',
                        helperText: 'Range: -90 to 90',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.location_on),
                        hintText: 'e.g., 80.2707',
                        helperText: 'Range: -180 to 180',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (lat != null && lng != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MedicalTheme.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.map, color: MedicalTheme.primaryTeal),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: MedicalTheme.darkSlate,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _useCurrentLocation,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Use Current Location'),
              style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.primaryTeal),
            ),
            
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safe Zone Radius',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _radiusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Radius (meters)',
                        prefixIcon: Icon(Icons.radar),
                        hintText: 'e.g., 100',
                        helperText: 'Recommended: 50-500 meters',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (radius != null)
                      Text(
                        'Safe zone will cover approximately ${(radius * 2).toStringAsFixed(0)}m diameter area',
                        style: const TextStyle(fontSize: 12, color: MedicalTheme.lightSlate),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            Card(
              child: SwitchListTile(
                title: const Text('Enable Safe Zone Alerts'),
                subtitle: const Text('Receive notifications when patient leaves this area'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
                activeColor: MedicalTheme.accentGreen,
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveGeofence,
                style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.primaryTeal),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Safe Zone'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
