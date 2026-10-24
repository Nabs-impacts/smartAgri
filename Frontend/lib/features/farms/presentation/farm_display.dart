import '../../catalog/domain/admin_area.dart';
import '../domain/farm.dart';

String? farmRegionName(Farm farm, List<AdminArea> areas) {
  final int? id = farm.adminAreaId;
  if (id == null) {
    return null;
  }
  for (final AdminArea area in areas) {
    if (area.id == id) {
      return area.name;
    }
  }
  return null;
}

String formatAreaHa(double area) {
  final String number = area == area.roundToDouble()
      ? area.toInt().toString()
      : area
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
  return '${number.replaceAll('.', ',')} ha';
}

String? farmLocationLine(Farm farm, List<AdminArea> areas) {
  final String? region = farmRegionName(farm, areas);
  final String? village = farm.village;
  final List<String> parts = <String>[
    if (village != null && village.isNotEmpty) village,
    if (region != null && region.isNotEmpty) region,
  ];
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' · ');
}
