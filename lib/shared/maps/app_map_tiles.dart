/// Shared map-tile helper used wherever SoilGood shows a map (onboarding location).
///
/// Configures free Carto Voyager tiles + attribution so we avoid the default
/// ugly OSM look. Not a page — feature maps call AppMapTiles.layer(context).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Shared free map tiles — Carto Voyager (cleaner than default OSM raster).
///
/// Attribution required: © OpenStreetMap © CARTO
abstract final class AppMapTiles {
  static const urlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  static const subdomains = ['a', 'b', 'c', 'd'];

  static const userAgentPackageName = 'com.soilsense.soil_sense';

  static const attribution = '© OpenStreetMap © CARTO';

  /// Builds the standard SoilGood base tile layer (sharp on high-DPI screens).
  static TileLayer layer(BuildContext context) {
    return TileLayer(
      urlTemplate: urlTemplate,
      subdomains: subdomains,
      userAgentPackageName: userAgentPackageName,
      retinaMode: RetinaMode.isHighDensity(context),
    );
  }
}
