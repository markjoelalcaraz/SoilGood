/// Onboarding step 2 screen — pick the farm GPS pin on a Carto Voyager map.
///
/// Shown before the shell so weather and analytics know where the farm is.
/// Farmer confirms location explicitly; coordinates are saved to arms.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/maps/app_map_tiles.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../data/onboarding_repository.dart';
import 'device_onboarding_page.dart';

/// Onboarding Step 2 — GPS detect + draggable map pin, then save farm.
class LocationOnboardingPage extends StatefulWidget {
  const LocationOnboardingPage({super.key});

  @override
  State<LocationOnboardingPage> createState() => _LocationOnboardingPageState();
}

class _LocationOnboardingPageState extends State<LocationOnboardingPage> {
  final _repo = OnboardingRepository();
  final _mapController = MapController();

  /// Default center (Laguna area) only until GPS resolves or user moves pin.
  LatLng _pin = const LatLng(14.312, 121.112);
  bool _loadingGps = true;
  bool _saving = false;
  String? _error;
  String? _gpsNote;

  @override
  void initState() {
    super.initState();
    _detectGps();
  }

  /// Requests permission and moves the pin to the phone GPS.
  Future<void> _detectGps() async {
    setState(() {
      _loadingGps = true;
      _error = null;
      _gpsNote = null;
    });

    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        throw StateError('Location services are turned off.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission denied. Drag the pin to your farm manually.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final next = LatLng(position.latitude, position.longitude);
      setState(() {
        _pin = next;
        _gpsNote = 'GPS detected — drag the pin if this is not your farm.';
        _loadingGps = false;
      });
      _mapController.move(next, 15);
    } on Object catch (e) {
      setState(() {
        _loadingGps = false;
        _error = e.toString();
        _gpsNote =
            'Could not use GPS. Drag the pin to your farm, then confirm.';
      });
    }
  }

  /// Persists farm coordinates then continues to device claim.
  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = await _repo.loadProfile();
      final barangay = (profile?['barangay'] as String?) ?? '';
      final city = (profile?['municipality_city'] as String?) ?? '';
      final province = (profile?['province'] as String?) ?? '';

      await _repo.saveFarmLocation(
        name: 'My Farm',
        barangay: barangay,
        municipalityCity: city,
        province: province,
        latitude: _pin.latitude,
        longitude: _pin.longitude,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppPageRoutes.slideFromRight(const DeviceOnboardingPage()),
      );
    } on Object catch (e) {
      setState(() {
        _error = 'Could not save farm location: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        title: Text(
          'Farm location',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Retry GPS',
            onPressed: _loadingGps ? null : _detectGps,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SoftCard(
              color: AppColors.primarySoft.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 2 of 3',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pin your farm on the map',
                    style: GoogleFonts.literata(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _gpsNote ??
                        'We use GPS first. Drag the pin if you are not at the farm.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AuthErrorBanner(message: _error),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pin,
                    initialZoom: 14,
                    onTap: (tapPosition, point) {
                      setState(() => _pin = point);
                    },
                  ),
                  children: [
                    AppMapTiles.layer(context),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pin,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_loadingGps)
                  const ColoredBox(
                    color: Color(0x66FFFFFF),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text(
                        AppMapTiles.attribution,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Text(
                    '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AuthPrimaryButton(
                    label: 'Use this location',
                    isLoading: _saving,
                    onPressed: _loadingGps ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
