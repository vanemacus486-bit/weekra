class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.downloadUri,
    required this.sha256,
  });

  final String version;
  final Uri downloadUri;
  final String sha256;
}

bool isNewerVersion(String candidate, String current) {
  final candidateVersion = _ParsedVersion.tryParse(candidate);
  final currentVersion = _ParsedVersion.tryParse(current);
  if (candidateVersion == null || currentVersion == null) {
    return false;
  }
  return candidateVersion.compareTo(currentVersion) > 0;
}

class _ParsedVersion implements Comparable<_ParsedVersion> {
  const _ParsedVersion(this.numbers, this.preRelease);

  final List<int> numbers;
  final List<String>? preRelease;

  static _ParsedVersion? tryParse(String input) {
    final normalized = input.trim().replaceFirst(RegExp(r'^v'), '');
    final withoutBuild = normalized.split('+').first;
    final parts = withoutBuild.split('-');
    final numberParts = parts.first.split('.');
    if (numberParts.isEmpty || numberParts.length > 3) {
      return null;
    }
    final numbers = <int>[];
    for (final part in numberParts) {
      final number = int.tryParse(part);
      if (number == null || number < 0) {
        return null;
      }
      numbers.add(number);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    final preRelease = parts.length > 1
        ? parts.skip(1).join('-').split('.')
        : null;
    if (preRelease != null && preRelease.any((part) => part.isEmpty)) {
      return null;
    }
    return _ParsedVersion(numbers, preRelease);
  }

  @override
  int compareTo(_ParsedVersion other) {
    for (var index = 0; index < numbers.length; index++) {
      final comparison = numbers[index].compareTo(other.numbers[index]);
      if (comparison != 0) {
        return comparison;
      }
    }

    if (preRelease == null && other.preRelease == null) {
      return 0;
    }
    if (preRelease == null) {
      return 1;
    }
    if (other.preRelease == null) {
      return -1;
    }

    final length = preRelease!.length > other.preRelease!.length
        ? preRelease!.length
        : other.preRelease!.length;
    for (var index = 0; index < length; index++) {
      if (index >= preRelease!.length) {
        return -1;
      }
      if (index >= other.preRelease!.length) {
        return 1;
      }
      final left = preRelease![index];
      final right = other.preRelease![index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      late final int comparison;
      if (leftNumber != null && rightNumber != null) {
        comparison = leftNumber.compareTo(rightNumber);
      } else if (leftNumber != null) {
        comparison = -1;
      } else if (rightNumber != null) {
        comparison = 1;
      } else {
        comparison = left.compareTo(right);
      }
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }
}
