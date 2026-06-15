import 'package:equatable/equatable.dart';

/// One choice in a single- or multi-select field's fixed option set.
///
/// [id] is the stable value stored on objects; [label] is the display text;
/// [color] is an optional `#RRGGBB` hint for chips/tags. Shared by the
/// single-select and multi-select field types.
class SelectOption extends Equatable {
  const SelectOption({
    required this.id,
    required this.label,
    this.color,
  });

  final String id;
  final String label;
  final String? color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (color != null) 'color': color,
      };

  factory SelectOption.fromJson(Map<String, dynamic> json) => SelectOption(
        id: json['id'] as String,
        label: json['label'] as String,
        color: json['color'] as String?,
      );

  @override
  List<Object?> get props => [id, label, color];
}
