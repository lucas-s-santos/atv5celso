import 'package:flutter/material.dart';
import 'colors.dart';

Color statusColor(String status) {
  switch (status) {
    case 'entregue':          return AppColors.delivered;
    case 'saiu para entrega': return AppColors.outForDelivery;
    case 'em transporte':     return AppColors.inTransit;
    default:                  return AppColors.pending;
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'entregue':          return Icons.check_circle_rounded;
    case 'saiu para entrega': return Icons.local_shipping_rounded;
    case 'em transporte':     return Icons.airport_shuttle_rounded;
    default:                  return Icons.inventory_2_rounded;
  }
}
