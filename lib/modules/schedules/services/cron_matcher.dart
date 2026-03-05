class CronMatcher {
  static bool isValidExpression(String expression) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      return false;
    }

    return _isValidField(parts[0], 0, 59) &&
        _isValidField(parts[1], 0, 23) &&
        _isValidField(parts[2], 1, 31) &&
        _isValidField(parts[3], 1, 12) &&
        _isValidField(parts[4], 0, 7);
  }

  static bool matches(String expression, DateTime time) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      return false;
    }

    final weekDay = time.weekday % 7;
    return _matchesField(parts[0], time.minute, 0, 59) &&
        _matchesField(parts[1], time.hour, 0, 23) &&
        _matchesField(parts[2], time.day, 1, 31) &&
        _matchesField(parts[3], time.month, 1, 12) &&
        _matchesField(parts[4], weekDay, 0, 7);
  }

  static DateTime? nextOccurrence(String expression, DateTime from) {
    if (!isValidExpression(expression)) {
      return null;
    }

    var cursor = DateTime(
      from.year,
      from.month,
      from.day,
      from.hour,
      from.minute,
    ).add(const Duration(minutes: 1));
    const maxIterations = 60 * 24 * 400;
    for (var i = 0; i < maxIterations; i++) {
      if (matches(expression, cursor)) {
        return cursor;
      }
      cursor = cursor.add(const Duration(minutes: 1));
    }
    return null;
  }

  static bool _isValidField(String raw, int min, int max) {
    final segments = raw.split(',');
    for (final segment in segments) {
      if (!_isValidSegment(segment.trim(), min, max)) {
        return false;
      }
    }
    return true;
  }

  static bool _isValidSegment(String segment, int min, int max) {
    if (segment == '*') return true;
    if (segment.startsWith('*/')) {
      final step = int.tryParse(segment.substring(2));
      return step != null && step > 0;
    }

    final stepParts = segment.split('/');
    if (stepParts.length == 2) {
      final step = int.tryParse(stepParts[1]);
      if (step == null || step <= 0) return false;
      return _isBaseValid(stepParts[0], min, max);
    }

    return _isBaseValid(segment, min, max);
  }

  static bool _isBaseValid(String base, int min, int max) {
    if (base == '*') return true;
    if (base.contains('-')) {
      final parts = base.split('-');
      if (parts.length != 2) return false;
      final start = int.tryParse(parts[0]);
      final end = int.tryParse(parts[1]);
      if (start == null || end == null) return false;
      return start >= min && end <= max && start <= end;
    }
    final value = int.tryParse(base);
    return value != null && value >= min && value <= max;
  }

  static bool _matchesField(String raw, int value, int min, int max) {
    final segments = raw.split(',');
    for (final segment in segments) {
      if (_matchesSegment(segment.trim(), value, min, max)) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesSegment(String segment, int value, int min, int max) {
    if (segment == '*') return true;
    if (segment.startsWith('*/')) {
      final step = int.parse(segment.substring(2));
      return (value - min) % step == 0;
    }

    final stepParts = segment.split('/');
    if (stepParts.length == 2) {
      final step = int.parse(stepParts[1]);
      return _valueInBase(stepParts[0], value, min, max) &&
          ((value - _baseStart(stepParts[0], min)) % step == 0);
    }

    return _valueInBase(segment, value, min, max);
  }

  static int _baseStart(String base, int min) {
    if (base == '*' || base.isEmpty) return min;
    if (base.contains('-')) {
      return int.parse(base.split('-').first);
    }
    return int.parse(base);
  }

  static bool _valueInBase(String base, int value, int min, int max) {
    if (base == '*') {
      return value >= min && value <= max;
    }
    if (base.contains('-')) {
      final parts = base.split('-');
      final start = int.parse(parts[0]);
      final endRaw = int.parse(parts[1]);
      final end = endRaw == 7 && max == 7 ? 0 : endRaw;
      final checked = value == 0 && max == 7 ? 0 : value;
      if (start <= endRaw) {
        return checked >= start && checked <= endRaw;
      }
      return checked >= start || checked <= end;
    }
    final parsed = int.parse(base);
    if (max == 7 && parsed == 7) {
      return value == 0;
    }
    return value == parsed;
  }
}
