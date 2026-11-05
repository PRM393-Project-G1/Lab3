import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import 'status_chip.dart';

/// Marks a topic whose references are mostly problematic.
class WeakTag extends StatelessWidget {
  const WeakTag({super.key});

  @override
  Widget build(BuildContext context) => const StatusChip(
    RefStatus.error,
    label: 'Weak',
    icon: Icons.warning_amber_rounded,
  );
}
