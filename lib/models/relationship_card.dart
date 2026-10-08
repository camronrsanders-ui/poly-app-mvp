class RelationshipCard {
  const RelationshipCard({
    required this.id,
    required this.ownerUid,
    required this.label,
    required this.connectionType,
    required this.displayNameOptional,
    required this.status,
    required this.note,
    required this.visibility,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String ownerUid;
  final String label;
  final String connectionType;
  final String displayNameOptional;
  final String status;
  final String note;
  final String visibility;
  final int sortOrder;
  final bool isActive;

  factory RelationshipCard.fromMap(String id, Map<String, dynamic> data) {
    return RelationshipCard(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      label: data['label'] as String? ?? '',
      connectionType: data['connectionType'] as String? ?? 'custom',
      displayNameOptional: data['displayNameOptional'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      note: data['note'] as String? ?? '',
      visibility: data['visibility'] as String? ?? 'matches_only',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'label': label,
        'connectionType': connectionType,
        'displayNameOptional': displayNameOptional,
        'status': status,
        'note': note,
        'visibility': visibility,
        'sortOrder': sortOrder,
        'isActive': isActive,
      };
}
