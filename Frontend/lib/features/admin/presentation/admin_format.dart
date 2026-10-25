import 'package:intl/intl.dart';

final NumberFormat _adminNumberFormat = NumberFormat.decimalPattern('fr');

String formatAdminNumber(num value) => _adminNumberFormat.format(value);
