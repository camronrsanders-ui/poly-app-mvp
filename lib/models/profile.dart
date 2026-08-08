class Profile {
  const Profile({
    required this.uid,
    required this.displayName,
    required this.age,
    required this.city,
    required this.region,
    required this.bio,
    required this.headline,
    required this.photoUrls,
    required this.avatarUrl,
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
  final List<String> photoUrls;
  final String avatarUrl;
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
    List<String> strings(String key) => List<String>.from(data[key] as List<dynamic>? ?? const []);

    return Profile(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 18,
      city: data['city'] as String? ?? '',
      region: data['region'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      headline: data['headline'] as String? ?? '',
      photoUrls: strings('photoUrls'),
      avatarUrl: data['avatarUrl'] as String? ?? '',
      genderIdentity: data['genderIdentity'] as String? ?? '',
      pronouns: data['pronouns'] as String? ?? '',
      orientation: data['orientation'] as String? ?? '',
      customIdentityTags: strings('customIdentityTags'),
      relationshipStructure: data['relationshipStructure'] as String? ?? '',
      relationshipStatus: data['relationshipStatus'] as String? ?? '',
      partnered: data['partnered'] as bool? ?? false,
      openToConnections: data['openToConnections'] as bool? ?? true,
      intentionTags: strings('intentionTags'),
      interests: strings('interests'),
      lookingForNote: data['lookingForNote'] as String? ?? '',
      ageMin: (data['ageMin'] as num?)?.toInt() ?? 18,
      ageMax: (data['ageMax'] as num?)?.toInt() ?? 99,
      distanceRadius: (data['distanceRadius'] as num?)?.toInt() ?? 50,
      preferredStructures: strings('preferredStructures'),
      preferredIntentions: strings('preferredIntentions'),
      profileVisibility: data['profileVisibility'] as String? ?? 'public',
      mapVisibility: data['mapVisibility'] as String? ?? 'matches_only',
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
        'photoUrls': photoUrls,
        'avatarUrl': avatarUrl,
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
