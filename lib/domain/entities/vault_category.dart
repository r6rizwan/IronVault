import 'package:flutter/material.dart';

class VaultCategory {
  final int? id; // null when not saved
  final String name;
  final String iconKey; // key from preset icon map
  final int colorValue; // Color.value

  VaultCategory({
    this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
  });

  VaultCategory copyWith({
    int? id,
    String? name,
    String? iconKey,
    int? colorValue,
  }) {
    return VaultCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconKey': iconKey,
      'colorValue': colorValue,
    };
  }

  factory VaultCategory.fromMap(Map<String, dynamic> m) {
    return VaultCategory(
      id: m['id'] as int?,
      name: m['name'] as String,
      iconKey: m['iconKey'] as String,
      colorValue: m['colorValue'] as int,
    );
  }

  Color get color => Color(colorValue);
}
