/// Farm tab inside the app shell: a map of the one saved farm.
///
/// One active crop can hold several sensors. Tapping that area grows the tile
/// and the crop plan rises underneath (phases, water week, care), then the
/// sensors on that crop. Plantings, sensors, and readings also arrive live
/// while this tab is open. Choosing a crop still opens the crop list.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/live/farm_live_hub.dart';
import '../../../core/live/farm_live_scope.dart';
import '../../../core/live/live_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../crops/data/crops_repository.dart';
import '../../crops/data/planting.dart';
import '../../crops/presentation/crop_plan_panel.dart';
import '../../crops/presentation/crops_page.dart';
import '../../shell/app_shell.dart';
import '../../weather/data/farm_location_repository.dart';
import '../data/farm_sensor.dart';
import '../data/plot_sensors_repository.dart';
import '../logic/crop_illustration.dart';
import 'add_sensor_page.dart';
import 'plot_sensor_card.dart';

/// Map of the farmer's farm. Shell content area, second-to-last tab.
class FarmMapPage extends StatefulWidget {
  const FarmMapPage({super.key});

  @override
  State<FarmMapPage> createState() => _FarmMapPageState();
}

class _FarmMapPageState extends State<FarmMapPage> with LivePage {
  final _farms = FarmLocationRepository();
  final _crops = CropsRepository();
  final _sensorsRepo = PlotSensorsRepository();

  String? _farmName;
  Planting? _planting;
  List<FarmSensor> _sensors = [];
  Object? _error;
  bool _loading = true;

  /// Bumped on each farm load so the open crop plan refetches care and water.
  int _planEpoch = 0;

  /// `sensor`, `crop`, or null for the even overview.
  String? _focus;

  @override
  Set<LiveSource> get liveSources => const {
    LiveSource.plantings,
    LiveSource.devices,
    LiveSource.farms,
    LiveSource.soil,
  };

  /// A planting, sensor, or new reading arrived. Keep the map, then reload.
  @override
  Future<void> onLive(Set<LiveSource> changed) => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Farm name plus the one active planting, if any.
  Future<void> _load() async {
    try {
      final farmId = await withRefreshTimeout(_farms.getPrimaryFarmId());
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      final name = await withRefreshTimeout(_farms.getPrimaryFarmName());
      final planting = await withRefreshTimeout(
        _crops.fetchActivePlanting(farmId),
      );
      final sensors = await withRefreshTimeout(
        _sensorsRepo.listForFarm(farmId),
      );
      if (!mounted) return;
      setState(() {
        _farmName = name;
        _planting = planting;
        _sensors = sensors;
        _error = null;
        _loading = false;
        _planEpoch++;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Crop list. When the farmer plants one, this area focuses and shows the plan.
  Future<void> _openCropPicker() async {
    final picked = await Navigator.of(context).push<bool>(
      AppPageRoutes.slideFromRight(const CropsPage()),
    );
    if (picked != true || !mounted) return;
    await _load();
    if (!mounted || _planting == null) return;
    setState(() => _focus = 'crop');
  }

  /// The plan ended the planting. Clear this area, then open the crop list.
  Future<void> _afterCropEnded() async {
    setState(() {
      _planting = null;
      _focus = null;
    });
    await _load();
    if (!mounted) return;
    await _openCropPicker();
  }

  Future<void> _addSensor() async {
    final planting = _planting;
    if (planting == null) return;
    final added = await Navigator.of(context).push<bool>(
      AppPageRoutes.slideFromRight(
        AddSensorPage(
          plantingId: planting.id,
          cropName: planting.crop.name,
        ),
      ),
    );
    if (added == true) await _load();
  }

  Future<void> _placeSensor(FarmSensor sensor) async {
    final planting = _planting;
    if (planting == null) return;
    try {
      await _sensorsRepo.placeOnPlot(
        deviceId: sensor.id,
        plantingId: planting.id,
      );
      await _load();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e is StateError ? e.message : e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planting = _planting;
    final cropAsset = planting == null
        ? null
        : cropIllustrationAsset(planting.crop.name);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'My farm', leadingIcon: Icons.spa),
      body: AppRefreshScroll(
        onRefresh: _load,
        children: [
          Text(
            _farmName ?? 'My farm',
            style: GoogleFonts.literata(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
            Text(
              planting == null
                  ? 'Sensor on this farm'
                  : '${planting.crop.name} · ${_sensors.where((s) => s.plantingId == planting.id).length} sensors',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            SoftCard(
              child: Text(
                'Could not load this farm:\n$_error',
                style: const TextStyle(color: AppColors.error, height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (FarmLiveScope.maybeOf(context)?.messageFor(liveSources) != null) ...[
            SoftCard(
              child: Text(
                FarmLiveScope.maybeOf(context)!.messageFor(liveSources)!,
                style: const TextStyle(color: AppColors.error, height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_loading && _farmName == null && _planting == null && _error == null)
            const SoftCard(
              color: AppColors.surfaceMuted,
              child: SizedBox(height: 220),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Chip(
                    label: 'Overview',
                    selected: _focus == null,
                    onTap: () => setState(() => _focus = null),
                  ),
                  if (planting != null) ...[
                    const SizedBox(width: 8),
                    _Chip(
                      label: planting.crop.name,
                      selected: _focus == 'crop',
                      onTap: () => setState(() => _focus = 'crop'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _FarmGrid(
              focus: _focus,
              cropName: planting?.crop.name,
              cropAsset: cropAsset,
              onSensor: () => setState(() => _focus = 'sensor'),
              onCrop: planting == null
                  ? _openCropPicker
                  : () => setState(() => _focus = 'crop'),
            ),
            const SizedBox(height: 12),
            _RiseIn(
              key: ValueKey(_focus ?? 'overview'),
              child: _focus == null
                  ? const SoftCard(
                      child: Text(
                        'Tap an area. It grows a little, and the rest dims.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : _focus == 'sensor'
                  ? const SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THIS SPOT',
                            style: TextStyle(
                              color: AppColors.navIcon,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Sensor kit',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Readings from this corner feed the crop area beside it.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    )
                  : planting != null
                  ? Column(
                      children: [
                        CropPlanPanel(
                          planting: planting,
                          refreshGeneration: _planEpoch,
                          onPlantingEnded: _afterCropEnded,
                        ),
                        const SizedBox(height: 12),
                        PlotSensorCard(
                          cropName: planting.crop.name,
                          onPlot: _sensors
                              .where((s) => s.plantingId == planting.id)
                              .toList(),
                          unplaced: _sensors
                              .where((s) => !s.onActivePlot)
                              .toList(),
                          onAdd: _addSensor,
                          onPlace: (sensor) => _placeSensor(sensor),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 2×2 map. The focused cell takes more of the frame. Nothing is scaled past the edges.
class _FarmGrid extends StatelessWidget {
  const _FarmGrid({
    required this.focus,
    required this.cropName,
    required this.cropAsset,
    required this.onSensor,
    required this.onCrop,
  });

  final String? focus;
  final String? cropName;
  final String? cropAsset;
  final VoidCallback onSensor;
  final VoidCallback onCrop;

  int _col(bool left) {
    if (focus == null) return 1;
    final growLeft = focus == 'sensor' || focus == 'crop';
    if (left) return growLeft ? 17 : 6;
    return growLeft ? 6 : 17;
  }

  int _row(bool top) {
    if (focus == null) return 1;
    if (focus == 'sensor') return top ? 17 : 6;
    if (focus == 'crop') return top ? 6 : 17;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFCFE3B8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Expanded(
            flex: _row(true),
            child: Row(
              children: [
                Expanded(
                  flex: _col(true),
                  child: _PlotTile(
                    label: 'Sensor',
                    asset: 'assets/crops/sensor.jpg',
                    dim: focus != null && focus != 'sensor',
                    selected: focus == 'sensor',
                    onTap: onSensor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: _col(false),
                  child: const _EmptyTile(label: 'Open ground'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: _row(false),
            child: Row(
              children: [
                Expanded(
                  flex: _col(true),
                  child: cropName == null
                      ? _EmptyTile(label: 'Choose a crop', onTap: onCrop)
                      : _PlotTile(
                          label: cropName!,
                          asset: cropAsset,
                          wind: true,
                          windPhase: cropName.hashCode,
                          dim: focus != null && focus != 'crop',
                          selected: focus == 'crop',
                          onTap: onCrop,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: _col(false),
                  child: const _EmptyTile(label: '+ Area'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade and a short rise the first time this block is shown.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.child, super.key});

  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

class _PlotTile extends StatelessWidget {
  const _PlotTile({
    required this.label,
    required this.asset,
    required this.dim,
    required this.selected,
    required this.onTap,
    this.wind = false,
    this.windPhase = 0,
  });

  final String label;
  final String? asset;
  final bool dim;
  final bool selected;
  final VoidCallback onTap;
  final bool wind;
  final int windPhase;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (asset != null && wind)
              _BreezyPlot(asset: asset!, phase: windPhase)
            else if (asset != null)
              Image.asset(asset!, fit: BoxFit.cover)
            else
              const ColoredBox(color: Color(0xFFCFE3B8)),
            if (dim) const ColoredBox(color: Color(0x7320181A)),
            if (selected)
              const DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF8ED15A), width: 3),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: dim ? 0.72 : 1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crop picture that leans in a slow breeze, with grass along the bottom.
class _BreezyPlot extends StatefulWidget {
  const _BreezyPlot({required this.asset, required this.phase});

  final String asset;
  final int phase;

  @override
  State<_BreezyPlot> createState() => _BreezyPlotState();
}

class _BreezyPlotState extends State<_BreezyPlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final extra = widget.phase.abs() % 5;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3200 + extra * 280),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * math.pi * 2;
        final sway = math.sin(angle);
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(sway * 6, 0),
              child: Transform.rotate(
                angle: sway * 0.02,
                child: Transform.scale(scale: 1.14, child: child),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 6; i++)
                    Transform.rotate(
                      alignment: Alignment.bottomCenter,
                      angle: math.sin(angle + i * 0.7) * 0.35,
                      child: Container(
                        width: 6,
                        height: i.isEven ? 18 : 13,
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? const Color(0xFF7DCE55)
                              : const Color(0xFF69B844),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      child: Image.asset(widget.asset, fit: BoxFit.cover),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x59FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.buttonGreen, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navIcon,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
