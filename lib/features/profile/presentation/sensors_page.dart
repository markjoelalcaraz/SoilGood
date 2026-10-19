/// Pushed page from Profile that lists every sensor and places it on a plot.
///
/// New kits and "Place on" go to the crop selected on Home / Farm (the farm
/// can grow several crops). Lives outside the shell content swap.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/live/farm_live_hub.dart';
import '../../../core/live/live_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../crops/data/crops_repository.dart';
import '../../crops/data/planting.dart';
import '../../crops/logic/selected_crop.dart';
import '../../farm/data/farm_sensor.dart';
import '../../farm/data/plot_sensors_repository.dart';
import '../../farm/presentation/add_sensor_page.dart';
import '../../weather/data/farm_location_repository.dart';

/// All kits on the farm, with the plot each one watches.
class SensorsPage extends StatefulWidget {
  const SensorsPage({super.key});

  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> with LivePage {
  final _farms = FarmLocationRepository();
  final _crops = CropsRepository();
  final _sensors = PlotSensorsRepository();

  bool _loading = true;
  Object? _error;
  String? _farmId;
  Planting? _planting;
  List<FarmSensor> _rows = [];

  @override
  Set<LiveSource> get liveSources => const {
    LiveSource.devices,
    LiveSource.soil,
    LiveSource.plantings,
  };

  /// A kit was claimed, moved, or sent a new reading.
  @override
  Future<void> onLive(Set<LiveSource> changed) => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Farm, current crop, and every claimed sensor.
  Future<void> _load() async {
    try {
      final farmId = await withRefreshTimeout(_farms.getPrimaryFarmId());
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      final plantings = await withRefreshTimeout(
        _crops.fetchActivePlantings(farmId),
      );
      await SelectedCrop.instance.restore();
      final planting = SelectedCrop.instance.resolve(plantings);
      final rows = await withRefreshTimeout(_sensors.listForFarm(farmId));
      if (!mounted) return;
      setState(() {
        _farmId = farmId;
        _planting = planting;
        _rows = rows;
        _error = null;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final planting = _planting;
    if (planting == null) {
      setState(() {
        _error = StateError(
          'Plant a crop on the Farm tab before adding a sensor to a plot.',
        );
      });
      return;
    }
    final added = await Navigator.of(context).push<bool>(
      AppPageRoutes.slideFromRight(
        AddSensorPage(plantingId: planting.id, cropName: planting.crop.name),
      ),
    );
    if (added == true) await _load();
  }

  Future<void> _place(FarmSensor sensor) async {
    final planting = _planting;
    if (planting == null) return;
    try {
      await _sensors.placeOnPlot(deviceId: sensor.id, plantingId: planting.id);
      await _load();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Farmer-facing text. StateError already carries the claim message.
  String _shownError(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final planting = _planting;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        title: Text(
          'Sensors',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: AppContentWidth(
        child: AppRefreshScroll(
          onRefresh: _load,
          children: [
            if (_loading && _rows.isEmpty)
              const SoftCard(
                child: Text(
                  'Loading sensors…',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else ...[
              Text(
                planting == null
                    ? 'Link a kit, then choose a crop to place it.'
                    : 'New kits go on ${planting.crop.name}.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                SoftCard(
                  child: Text(
                    'Could not update sensors:\n${_shownError(_error!)}',
                    style: const TextStyle(color: AppColors.error, height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_rows.isEmpty)
                const SoftCard(
                  child: Text(
                    'No sensors on this farm yet.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                )
              else
                for (final sensor in _rows) ...[
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sensor.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sensor.onActivePlot
                              ? sensor.cropName!
                              : 'No plot yet',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!sensor.onActivePlot && planting != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => _place(sensor),
                              child: Text('Place on ${planting.crop.name}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _farmId == null ? null : _add,
                  child: const Text('Add sensor'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
