String categoryId(String label) {
  final value = label.toLowerCase();
  for (final entry in <String, List<String>>{
    'refrigerator': ['refrig', 'fridge', '🧊'],
    'electrical': ['electric', '💡'],
    'ac': ['ac repair', '❄'],
    'satellite': ['dish', 'satellite', '📡'],
    'plumbing': ['plumb', '🚰'],
    'tv': ['tv', '📺'],
    'washing': ['wash', '🫧'],
    'cctv': ['cctv'],
    'water-pump': ['pump'],
    'computer': ['computer'],
    'microwave': ['microwave'],
  }.entries) {
    if (entry.value.any(value.contains)) return entry.key;
  }
  return 'other';
}
