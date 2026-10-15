/// Maps a catalog crop name to its shared top-down plot picture.
///
/// Used by the Farm tab grid. Files live in `assets/crops/` and match
/// `illustration_path` in `docs/context/supabase_crop_illustrations.sql`.
/// Not a screen.
library;

/// Asset path for [cropName], or null when this catalog crop has no tile yet.
String? cropIllustrationAsset(String cropName) {
  final name = cropName.toLowerCase();
  const named = <String, String>{
    'rice': 'assets/crops/rice.jpg',
    'palay': 'assets/crops/rice.jpg',
    'corn': 'assets/crops/corn.jpg',
    'mais': 'assets/crops/corn.jpg',
    'tomato': 'assets/crops/tomato.jpg',
    'eggplant': 'assets/crops/eggplant.jpg',
    'talong': 'assets/crops/eggplant.jpg',
    'ampalaya': 'assets/crops/ampalaya.jpg',
    'sitaw': 'assets/crops/sitaw.jpg',
    'okra': 'assets/crops/okra.jpg',
    'cabbage': 'assets/crops/cabbage.jpg',
    'repolyo': 'assets/crops/cabbage.jpg',
    'onion': 'assets/crops/onion.jpg',
    'sibuyas': 'assets/crops/onion.jpg',
    'garlic': 'assets/crops/garlic.jpg',
    'bawang': 'assets/crops/garlic.jpg',
    'chili': 'assets/crops/chili.jpg',
    'sili': 'assets/crops/chili.jpg',
    'cucumber': 'assets/crops/cucumber.jpg',
    'pipino': 'assets/crops/cucumber.jpg',
    'squash': 'assets/crops/squash.jpg',
    'kalabasa': 'assets/crops/squash.jpg',
    'peanut': 'assets/crops/peanut.jpg',
    'mani': 'assets/crops/peanut.jpg',
    'cassava': 'assets/crops/cassava.jpg',
    'kamoteng': 'assets/crops/cassava.jpg',
    'sweet potato': 'assets/crops/sweet-potato.jpg',
    'kamote': 'assets/crops/sweet-potato.jpg',
    'banana': 'assets/crops/banana.jpg',
    'saba': 'assets/crops/banana.jpg',
  };
  for (final entry in named.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return null;
}
