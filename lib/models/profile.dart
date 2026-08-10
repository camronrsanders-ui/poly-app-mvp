class Profile {
  const Profile({
    required this.uid,
    required this.displayName,
    required this.age,
    required this.city,
    required this.region,
    required this.bio,
    required this.headline,
    required this.genderIdentity,
    required this.pronouns,
    required this.orientation,
    required this.customIdentityTags,
    required this.relationshipStructure,
    required this.relationshipStatus,
    required this.partnered,
    required this.openToConnections,
    required this.intentionTags,
    required this.interests,
    required this.lookingForNote,
    required this.ageMin,
    required this.ageMax,
    required this.distanceRadius,
    required this.preferredStructures,
    required this.preferredIntentions,
    required this.profileVisibility,
    required this.mapVisibility,
  });

  final String uid;
  final String displayName;
  final int age;
  final String city;
  final String region;
  final String bio;
  final String headline;
  final String genderIdentity;
  final String pronouns;
  final String orientation;
  final List<String> customIdentityTags;
  final String relationshipStructure;
  final String relationshipStatus;
  final bool partnered;
  final bool openToConnections;
  final List<String> intentionTags;
  final List<String> interests;
  final String lookingForNote;
  final int ageMin;
  final int ageMax;
  final int distanceRadius;
  final List<String> preferredStructures;
  final List<String> preferredIntentions;
  final String profileVisibility;
  final String mapVisibility;

  factory Profile.fromMap(String uid, Map<String, dynamic> data) {
    String stringValue(String key, [String fallback = '']) {
      final value = data[key];
      return value is String ? value : fallback;
    }

    int intValue(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    bool boolValue(String key, bool fallback) {
      final value = data[key];
      return value is bool ? value : fallback;
    }

    List<String> strings(String key) {
      final value = data[key];
      if (value is! List) return const [];
      return value.whereType<String>().toList(growable: false);
    }

    return Profile(
      uid: uid,
      displayName: stringValue('displayName'),
      age: intValue('age', 18),
      city: stringValue('city'),
      region: stringValue('region'),
      bio: stringValue('bio'),
      headline: stringValue('headline'),
      genderIdentity: stringValue('genderIdentity'),
      pronouns: stringValue('pronouns'),
      orientation: stringValue('orientation'),
      customIdentityTags: strings('customIdentityTags'),
      relationshipStructure: stringValue('relationshipStructure'),
      relationshipStatus: stringValue('relationshipStatus'),
      partnered: boolValue('partnered', false),
      openToConnections: boolValue('openToConnections', true),
      intentionTags: strings('intentionTags'),
      interests: strings('interests'),
      lookingForNote: stringValue('lookingForNote'),
      ageMin: intValue('ageMin', 18),
      ageMax: intValue('ageMax', 99),
      distanceRadius: intValue('distanceRadius', 50),
      preferredStructures: strings('preferredStructures'),
      preferredIntentions: strings('preferredIntentions'),
      profileVisibility: stringValue('profileVisibility', 'public'),
      mapVisibility: stringValue('mapVisibility', 'matches_only'),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'age': age,
        'city': city,
        'region': region,
        'bio': bio,
        'headline': headline,
        'genderIdentity': genderIdentity,
        'pronouns': pronouns,
        'orientation': orientation,
        'customIdentityTags': customIdentityTags,
        'relationshipStructure': relationshipStructure,
        'relationshipStatus': relationshipStatus,
        'partnered': partnered,
        'openToConnections': openToConnections,
        'intentionTags': intentionTags,
        'interests': interests,
        'lookingForNote': lookingForNote,
        'ageMin': ageMin,
        'ageMax': ageMax,
        'distanceRadius': distanceRadius,
        'preferredStructures': preferredStructures,
        'preferredIntentions': preferredIntentions,
        'profileVisibility': profileVisibility,
        'mapVisibility': mapVisibility,
      };
}
