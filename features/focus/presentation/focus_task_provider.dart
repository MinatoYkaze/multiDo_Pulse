import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';

/// Task the user chose to focus on ("Start Focus on this Task").
/// Phase 5's Focus screen reads and clears this.
final focusTaskProvider = StateProvider<Tasks?>((_) => null);
