import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const documentTypes = [
  'NATIONAL_ID',
  'BUSINESS_LICENSE',
  'TIN_CERTIFICATE',
  'OTHER',
];

String documentTypeLabel(String type) {
  switch (type) {
    case 'NATIONAL_ID':
      return 'Kitambulisho (NIDA / Mpiga Kura / Pasipoti)';
    case 'BUSINESS_LICENSE':
      return 'Leseni ya Biashara / BRELA';
    case 'TIN_CERTIFICATE':
      return 'Cheti cha TIN (TRA)';
    default:
      return 'Nyaraka Nyingine';
  }
}

String accountTypeLabel(String? type) {
  switch (type) {
    case 'COMPANY':
      return 'Kampuni';
    case 'INDIVIDUAL':
      return 'Mtu Binafsi';
    default:
      return '-';
  }
}

({String label, Color color, IconData icon}) verificationStyle(String status) {
  switch (status) {
    case 'VERIFIED':
    case 'APPROVED':
      return (
        label: 'Amethibitishwa',
        color: AppColors.statusCompleted,
        icon: Icons.verified_rounded,
      );
    case 'REJECTED':
      return (
        label: 'Amekataliwa',
        color: AppColors.statusDisputed,
        icon: Icons.cancel_rounded,
      );
    default:
      return (
        label: 'Inasubiri',
        color: AppColors.accentDark,
        icon: Icons.hourglass_top_rounded,
      );
  }
}
