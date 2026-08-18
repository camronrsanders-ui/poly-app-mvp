const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {FieldValue, Timestamp, getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {readFile} = require('node:fs/promises');
const path = require('node:path');

const nativeFirebaseProjectId = 'poly-circle-j5v6dy';

function isLoopbackEmulatorHost(value) {
  if (typeof value !== 'string') return false;
  return /^(?:127\.0\.0\.1|localhost|\[?::1\]?):\d+$/.test(value.trim());
}

function requireEmulatorEnvironment() {
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  if (!firestoreHost || !authHost) {
    throw new Error(
      'Refusing to seed: FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST must both be set.',
    );
  }
  if (!storageHost) {
    throw new Error(
      'Refusing to seed profile photos: FIREBASE_STORAGE_EMULATOR_HOST must be set.',
    );
  }
  if (
    !isLoopbackEmulatorHost(firestoreHost)
    || !isLoopbackEmulatorHost(authHost)
    || !isLoopbackEmulatorHost(storageHost)
  ) {
    throw new Error(
      'Refusing to seed: emulator hosts must be loopback addresses (127.0.0.1, localhost, or ::1).',
    );
  }

  let firebaseConfig = {};
  try {
    firebaseConfig = process.env.FIREBASE_CONFIG
      ? JSON.parse(process.env.FIREBASE_CONFIG)
      : {};
  } catch (_) {
    // A malformed config should never make the production guard less strict.
  }
  const projectId = process.env.GCLOUD_PROJECT
    || process.env.GOOGLE_CLOUD_PROJECT
    || firebaseConfig.projectId
    || '';

  const demoProject = projectId.startsWith('demo-');
  const explicitlyApprovedNativeProject = projectId === nativeFirebaseProjectId
    && process.env.POLYCIRCLE_ALLOW_REAL_PROJECT_EMULATOR === 'true';
  if (!demoProject && !explicitlyApprovedNativeProject) {
    throw new Error(
      `Refusing to seed project "${projectId || '[unknown]'}". Use a demo-* project, or use the guarded Polycircle local runner for ${nativeFirebaseProjectId}.`,
    );
  }
  return projectId;
}

const projectId = requireEmulatorEnvironment();
initializeApp({projectId});

const auth = getAuth();
const db = getFirestore();
const storage = getStorage();
const password = 'LocalOnly123!';
const allowedDiscoverFixtureCounts = new Set([2, 5, 10, 15, 45]);
const allowedDiscoverFixtureRadii = new Set([5, 10, 20, 30, 50, 100]);

function readDiscoverFixtureCount() {
  const raw = process.env.POLYCIRCLE_DISCOVER_FIXTURE_COUNT ?? '2';
  const count = Number(raw);
  if (!Number.isInteger(count) || !allowedDiscoverFixtureCounts.has(count)) {
    throw new Error(
      `POLYCIRCLE_DISCOVER_FIXTURE_COUNT must be one of 2, 5, 10, 15, or 45; received "${raw}".`,
    );
  }
  return count;
}

function readDiscoverFixtureRadius() {
  const raw = process.env.POLYCIRCLE_DISCOVER_FIXTURE_RADIUS ?? '20';
  const radius = Number(raw);
  if (!Number.isInteger(radius) || !allowedDiscoverFixtureRadii.has(radius)) {
    throw new Error(
      `POLYCIRCLE_DISCOVER_FIXTURE_RADIUS must be 5, 10, 20, 30, 50, or 100; received "${raw}".`,
    );
  }
  return radius;
}

const discoverFixtureCount = readDiscoverFixtureCount();
const discoverFixtureRadius = readDiscoverFixtureRadius();
const discoverPortraitDirectory = path.join(
  __dirname,
  '..',
  'fixtures',
  'discover_portraits',
);
// Fictional point in the North Atlantic, used only by guarded local emulators.
// No real member or founder coordinates belong in fixture data.
const localDiscoverOrigin = {latitude: 12.3456, longitude: -45.6789};
const discoverFixtureDistancesMiles = [
  2, 7, 15, 28, 60, 3, 9, 18, 35, 75, 4, 12, 24, 45, 90,
  1, 6, 14, 27, 58, 3.5, 8, 19, 38, 78, 4.5, 11, 23, 48, 92,
  2.5, 7.5, 16, 30, 62, 4, 10, 21, 42, 82, 5, 13, 26, 50, 95,
];

const people = [
  {
    uid: 'local-cam',
    email: 'cam@local.polycircle.test',
    displayName: 'Cam',
    age: 29,
    city: 'Boston',
    region: 'MA',
    headline: 'Building an honest, connected circle',
    bio: 'Local emulator account for testing the Polycircle owner experience.',
    genderIdentity: 'Man',
    pronouns: 'he/him',
    orientation: 'Gay',
    relationshipStructure: 'Polyamorous',
    relationshipStatus: 'Open to connections',
    partnered: false,
    openToConnections: true,
    intentionTags: ['Dating', 'Friendship'],
    interests: ['Travel', 'Food', 'Community'],
    lookingForNote: 'Open communication and genuine connection.',
  },
  {
    uid: 'local-alex',
    email: 'alex@local.polycircle.test',
    displayName: 'Alex',
    age: 31,
    city: 'Cambridge',
    region: 'MA',
    headline: 'Good conversation, good boundaries',
    bio: 'A seeded Discover profile for local testing.',
    genderIdentity: 'Nonbinary',
    pronouns: 'they/them',
    orientation: 'Queer',
    relationshipStructure: 'Relationship anarchy',
    relationshipStatus: 'Dating',
    partnered: true,
    openToConnections: true,
    intentionTags: ['Dating', 'Friendship'],
    interests: ['Art', 'Cooking', 'Live music'],
    lookingForNote: 'Kind people who communicate clearly.',
  },
  {
    uid: 'local-riley',
    email: 'riley@local.polycircle.test',
    displayName: 'Riley',
    age: 27,
    city: 'Somerville',
    region: 'MA',
    headline: 'Friends first, chemistry welcome',
    bio: 'A second seeded Discover profile for Pass and filtering tests.',
    genderIdentity: 'Woman',
    pronouns: 'she/her',
    orientation: 'Bisexual',
    relationshipStructure: 'Open relationship',
    relationshipStatus: 'Partnered',
    partnered: true,
    openToConnections: true,
    intentionTags: ['Friendship', 'Dating'],
    interests: ['Kickball', 'Movies', 'Coffee'],
    lookingForNote: 'Community, friendship, and respectful dating.',
  },
  {
    uid: 'local-jordan',
    email: 'jordan@local.polycircle.test',
    displayName: 'Jordan',
    age: 33,
    city: 'Medford',
    region: 'MA',
    headline: 'Existing connection for messaging tests',
    bio: 'A seeded matched profile with an active conversation.',
    genderIdentity: 'Man',
    pronouns: 'he/him',
    orientation: 'Queer',
    relationshipStructure: 'Polyamorous',
    relationshipStatus: 'Partnered',
    partnered: true,
    openToConnections: false,
    intentionTags: ['Friendship'],
    interests: ['Games', 'Photography', 'Travel'],
    lookingForNote: 'Already connected in this local fixture.',
  },
  {
    uid: 'local-moderator',
    email: 'moderator@local.polycircle.test',
    displayName: 'Local Moderator',
    age: 30,
    city: 'Boston',
    region: 'MA',
    headline: 'Local moderation QA only',
    bio: 'Hidden emulator-only staff fixture for trusted moderation testing.',
    genderIdentity: '',
    pronouns: '',
    orientation: '',
    relationshipStructure: '',
    relationshipStatus: '',
    partnered: false,
    openToConnections: false,
    intentionTags: [],
    interests: [],
    lookingForNote: '',
    profileVisibility: 'hidden',
    authClaims: {moderator: true},
  },
];

// These people exist only inside the guarded emulator seed. They are never
// referenced by production code and allow realistic Orbit density checks
// without weakening profile, discovery, or protected-media behavior.
const discoverStressDetails = [
  ['Morgan', 34, 'Boston', 'MA', 'they/them', 'Solo poly', 'Museum afternoons and honest conversation', ['Art', 'Cycling', 'Community']],
  ['Jules', 29, 'Brookline', 'MA', 'she/they', 'Non-hierarchical poly', 'Soft mornings, bold food, clear intentions', ['Cooking', 'Books', 'Gardens']],
  ['Avery', 32, 'Cambridge', 'MA', 'he/they', 'Relationship anarchy', 'Curious people make the best stories', ['Film', 'Travel', 'Design']],
  ['Quinn', 28, 'Somerville', 'MA', 'they/them', 'Exploring', 'Here for friendship, laughter, and possibility', ['Comedy', 'Coffee', 'Hiking']],
  ['Sage', 36, 'Jamaica Plain', 'MA', 'she/her', 'Polyamorous', 'Building community one dinner at a time', ['Food', 'Music', 'Volunteering']],
  ['Rowan', 30, 'Medford', 'MA', 'he/him', 'Open relationship', 'Live music and emotionally fluent humans', ['Concerts', 'Photography', 'Running']],
  ['Devon', 27, 'Boston', 'MA', 'they/he', 'Solo poly', 'Making room for meaningful surprises', ['Theater', 'Games', 'Travel']],
  ['Skyler', 33, 'Quincy', 'MA', 'she/they', 'Polyamorous', 'Slow connection, big curiosity', ['Ceramics', 'Nature', 'Podcasts']],
  ['Ellis', 31, 'Cambridge', 'MA', 'they/them', 'Relationship anarchy', 'Kindness, candor, and a little adventure', ['Climbing', 'Books', 'Cooking']],
  ['Parker', 35, 'Boston', 'MA', 'he/him', 'Non-hierarchical poly', 'City walks and conversations that wander', ['Architecture', 'Coffee', 'Jazz']],
  ['Drew', 26, 'Somerville', 'MA', 'she/her', 'Exploring', 'Community first, chemistry welcome', ['Dance', 'Movies', 'Food']],
  ['Taylor', 38, 'Newton', 'MA', 'they/she', 'Open relationship', 'Grounded, playful, and always learning', ['Gardening', 'Travel', 'Live music']],
  ['Reese', 29, 'Malden', 'MA', 'he/they', 'Polyamorous', 'Looking for warmth, wit, and intention', ['Gaming', 'Art', 'Community']],
  ['Remy', 34, 'Watertown', 'MA', 'they/them', 'Solo poly', 'Making space for care and good questions', ['Poetry', 'Hiking', 'Food']],
  ['Noa', 30, 'Arlington', 'MA', 'she/her', 'Polyamorous', 'A little wonder goes a long way', ['Science', 'Dance', 'Travel']],
  ['Mika', 37, 'Boston', 'MA', 'he/him', 'Open relationship', 'Thoughtful plans and spontaneous detours', ['Music', 'Running', 'Cooking']],
  ['Lane', 28, 'Somerville', 'MA', 'they/she', 'Relationship anarchy', 'Here for sincerity and shared delight', ['Theater', 'Books', 'Coffee']],
  ['Kit', 33, 'Cambridge', 'MA', 'they/he', 'Non-hierarchical poly', 'Learning, laughing, and showing up', ['Design', 'Games', 'Community']],
  ['Jamie', 31, 'Medford', 'MA', 'she/her', 'Exploring', 'Kind company for everyday adventures', ['Cycling', 'Film', 'Gardens']],
  ['Ari', 35, 'Brookline', 'MA', 'he/they', 'Polyamorous', 'Clear communication and curious weekends', ['Art', 'Travel', 'Food']],
  ['Robin', 29, 'Boston', 'MA', 'they/them', 'Solo poly', 'Warm conversation and room to grow', ['Books', 'Yoga', 'Podcasts']],
  ['Marin', 36, 'Quincy', 'MA', 'she/they', 'Open relationship', 'Community care with a playful streak', ['Volunteering', 'Music', 'Cooking']],
  ['Shiloh', 32, 'Cambridge', 'MA', 'he/him', 'Relationship anarchy', 'Slow mornings and bright ideas', ['Coffee', 'Architecture', 'Running']],
  ['Emery', 27, 'Somerville', 'MA', 'they/she', 'Exploring', 'Friendship, chemistry, and honest pacing', ['Dance', 'Film', 'Climbing']],
  ['Finley', 39, 'Newton', 'MA', 'they/them', 'Polyamorous', 'Grounded connection and joyful curiosity', ['Gardening', 'Jazz', 'Travel']],
  ['Cameron', 30, 'Malden', 'MA', 'he/they', 'Solo poly', 'Making meaningful room for one another', ['Gaming', 'Community', 'Art']],
  ['Dakota', 34, 'Boston', 'MA', 'she/her', 'Open relationship', 'Good food and direct communication', ['Cooking', 'Museums', 'Cycling']],
  ['Charlie', 28, 'Arlington', 'MA', 'they/them', 'Relationship anarchy', 'Delightfully earnest about connection', ['Poetry', 'Nature', 'Theater']],
  ['Frankie', 37, 'Watertown', 'MA', 'she/they', 'Non-hierarchical poly', 'Seeking warmth without shortcuts', ['Books', 'Food', 'Design']],
  ['Kai', 31, 'Cambridge', 'MA', 'he/him', 'Polyamorous', 'Care, humor, and the occasional road trip', ['Travel', 'Comedy', 'Music']],
  ['Sam', 33, 'Medford', 'MA', 'they/he', 'Solo poly', 'Independent lives, intentional connection', ['Photography', 'Running', 'Games']],
  ['Micah', 29, 'Boston', 'MA', 'they/them', 'Exploring', 'Curiosity with clear boundaries', ['Science', 'Coffee', 'Film']],
  ['Lennon', 35, 'Brookline', 'MA', 'she/her', 'Open relationship', 'Creative days and honest nights', ['Ceramics', 'Dance', 'Gardens']],
  ['Tatum', 32, 'Somerville', 'MA', 'they/she', 'Relationship anarchy', 'Building trust one conversation at a time', ['Community', 'Books', 'Hiking']],
  ['River', 38, 'Quincy', 'MA', 'he/they', 'Polyamorous', 'Playful spirit, practical communicator', ['Cooking', 'Music', 'Travel']],
  ['Casey', 27, 'Boston', 'MA', 'they/them', 'Solo poly', 'Friendship is a wonderful beginning', ['Art', 'Cycling', 'Movies']],
  ['Bailey', 36, 'Newton', 'MA', 'she/they', 'Non-hierarchical poly', 'Present, curious, and community-minded', ['Volunteering', 'Gardening', 'Jazz']],
  ['Hayden', 30, 'Cambridge', 'MA', 'he/him', 'Open relationship', 'Coffee walks and thoughtful follow-through', ['Coffee', 'Architecture', 'Podcasts']],
  ['Arden', 34, 'Malden', 'MA', 'they/she', 'Relationship anarchy', 'Tenderness, candor, and room to roam', ['Poetry', 'Travel', 'Nature']],
  ['Blake', 28, 'Medford', 'MA', 'he/they', 'Exploring', 'Making friends and seeing what unfolds', ['Games', 'Film', 'Food']],
  ['Wren', 31, 'Boston', 'MA', 'they/them', 'Solo poly', 'Here for people who mean what they say', ['Books', 'Music', 'Community']],
  ['Sydney', 37, 'Arlington', 'MA', 'she/her', 'Polyamorous', 'Big-hearted, well-boundaried, and curious', ['Dance', 'Cooking', 'Museums']],
  ['Rory', 33, 'Watertown', 'MA', 'they/he', 'Open relationship', 'Good questions and unhurried connection', ['Hiking', 'Photography', 'Coffee']],
];

const discoverStressPeople = discoverStressDetails.map((details, index) => {
  const [displayName, age, city, region, pronouns, relationshipStructure, headline, interests] = details;
  const ordinal = String(index + 1).padStart(2, '0');
  return {
    uid: `local-discover-${ordinal}`,
    email: `discover-${ordinal}@local.polycircle.test`,
    displayName,
    age,
    city,
    region,
    headline,
    bio: 'Emulator-only Orbit stress profile for local visual testing.',
    genderIdentity: 'Self-described',
    pronouns,
    orientation: 'Queer',
    relationshipStructure,
    relationshipStatus: 'Open to connections',
    partnered: index % 3 !== 0,
    openToConnections: true,
    intentionTags: index % 2 === 0 ? ['Friendship', 'Dating'] : ['Community', 'Dating'],
    interests,
    lookingForNote: 'Intentional connection with room for people to be themselves.',
  };
});

const baselineDiscoverPeople = people.filter(
  (person) => person.uid === 'local-alex' || person.uid === 'local-riley',
);
const allDiscoverPeople = [...baselineDiscoverPeople, ...discoverStressPeople];
const selectedStressPeople = discoverStressPeople.slice(0, discoverFixtureCount - 2);
const selectedDiscoverPeople = [...baselineDiscoverPeople, ...selectedStressPeople];
const seededPeople = [...people, ...selectedStressPeople];

async function upsertAuthUser(person) {
  try {
    await auth.getUser(person.uid);
    await auth.updateUser(person.uid, {
      email: person.email,
      password,
      emailVerified: true,
      disabled: false,
    });
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
    await auth.createUser({
      uid: person.uid,
      email: person.email,
      password,
      emailVerified: true,
      disabled: false,
    });
  }
  // Explicitly set (or clear) claims on every seed so stale local privileges
  // cannot survive between fixture revisions.
  await auth.setCustomUserClaims(person.uid, person.authClaims ?? {});
}

async function seedPerson(person) {
  await upsertAuthUser(person);
  await db.collection('users').doc(person.uid).set({
    uid: person.uid,
    email: person.email,
    createdAt: FieldValue.serverTimestamp(),
    onboardingComplete: true,
    lastActiveAt: FieldValue.serverTimestamp(),
    accountStatus: 'active',
  }, {merge: true});

  // Auth-only fields such as email and staff claims must never be copied into
  // profiles. Keeping local fixtures inside the production profile schema
  // ensures owner edits are still accepted by the real Firestore rules.
  const {email: _email, authClaims: _authClaims, ...profile} = person;
  await db.collection('profiles').doc(person.uid).set({
    ...profile,
    customIdentityTags: [],
    ageMin: 18,
    ageMax: 99,
    distanceRadius: person.uid === 'local-cam' ? discoverFixtureRadius : 100,
    preferredStructures: [],
    preferredIntentions: [],
    profileVisibility: person.profileVisibility ?? 'public',
    mapVisibility: 'private',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

function fictionalCoordinateAtDistance(distanceMiles) {
  const longitudeMilesPerDegree = 69.172
    * Math.cos(localDiscoverOrigin.latitude * Math.PI / 180);
  return {
    latitude: localDiscoverOrigin.latitude,
    longitude: localDiscoverOrigin.longitude + distanceMiles / longitudeMilesPerDegree,
  };
}

const waitForLocalEmulator = (milliseconds) => new Promise(
  (resolve) => setTimeout(resolve, milliseconds),
);

async function saveDiscoverFixturePhoto(file, bytes, metadata) {
  const maximumAttempts = 4;
  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    try {
      await file.save(bytes, {
        resumable: false,
        metadata,
      });
      // Storage finalize events are asynchronous. A small local-only pause
      // prevents the Functions/Storage emulators from receiving all 45
      // protected-photo events in one burst on modest development machines.
      await waitForLocalEmulator(250);
      return;
    } catch (error) {
      const retryable = ['ECONNRESET', 'ECONNREFUSED', 'ETIMEDOUT']
        .includes(error?.code);
      if (!retryable || attempt === maximumAttempts) throw error;
      await waitForLocalEmulator(attempt * 400);
    }
  }
}

async function seedDiscoverLocations() {
  const batch = db.batch();
  const now = Timestamp.now();
  batch.set(db.collection('member_locations').doc('local-cam'), {
    uid: 'local-cam',
    ...localDiscoverOrigin,
    accuracyMeters: 250,
    source: 'emulator_fixture',
    observedAt: now,
    updatedAt: now,
  });
  selectedDiscoverPeople.forEach((person, index) => {
    batch.set(db.collection('member_locations').doc(person.uid), {
      uid: person.uid,
      ...fictionalCoordinateAtDistance(discoverFixtureDistancesMiles[index]),
      accuracyMeters: 250,
      source: 'emulator_fixture',
      observedAt: now,
      updatedAt: now,
    });
  });
  await batch.commit();
}

async function seedDiscoverPhotos() {
  const selectedUids = new Set(selectedDiscoverPeople.map((person) => person.uid));
  const bucket = storage.bucket(`${projectId}.firebasestorage.app`);
  const now = Timestamp.now();

  for (let index = 0; index < allDiscoverPeople.length; index += 1) {
    const person = allDiscoverPeople[index];
    const ordinal = String(index + 1).padStart(2, '0');
    const photoId = `local-discover-photo-${ordinal}`;
    const storagePath = `users/${person.uid}/profile/${photoId}.jpg`;
    const mediaRef = db.collection('profile_media').doc(photoId);
    const file = bucket.file(storagePath);

    if (!selectedUids.has(person.uid)) {
      await mediaRef.delete();
      await file.delete({ignoreNotFound: true});
      continue;
    }

    const portraitOrdinal = String((index % 15) + 1).padStart(2, '0');
    const bytes = await readFile(
      path.join(discoverPortraitDirectory, `profile-${portraitOrdinal}.jpg`),
    );
    await saveDiscoverFixturePhoto(file, bytes, {
      contentType: 'image/jpeg',
      metadata: {
        ownerUid: person.uid,
        photoId,
        processed: 'true',
        emulatorFixture: 'true',
      },
    });
    await mediaRef.set({
      photoId,
      ownerUid: person.uid,
      status: 'active',
      contentType: 'image/jpeg',
      storagePath,
      createdAt: now,
      processedAt: now,
      reviewedAt: now,
      emulatorFixture: true,
    });
  }
}

async function seedExistingConnection() {
  const userAUid = 'local-cam';
  const userBUid = 'local-jordan';
  const pairId = [userAUid, userBUid].sort().join('_');
  const now = Date.now();

  await db.collection('matches').doc(pairId).set({
    matchId: pairId,
    userAUid,
    userBUid,
    active: true,
    createdAt: Timestamp.fromMillis(now - 60 * 60 * 1000),
  });

  await db.collection('conversations').doc(pairId).set({
    conversationId: pairId,
    participantUids: [userAUid, userBUid].sort(),
    active: true,
    createdAt: Timestamp.fromMillis(now - 55 * 60 * 1000),
    lastMessageAt: Timestamp.fromMillis(now - 5 * 60 * 1000),
  });

  await Promise.all([
    db.collection('messages').doc('local-message-1').set({
      conversationId: pairId,
      senderUid: 'local-jordan',
      text: 'Hey! This is a seeded local conversation.',
      createdAt: Timestamp.fromMillis(now - 10 * 60 * 1000),
      isDeleted: false,
      messageType: 'text',
      readBy: ['local-jordan'],
    }),
    db.collection('messages').doc('local-message-2').set({
      conversationId: pairId,
      senderUid: 'local-cam',
      text: 'Perfect — messaging is connected to the emulator.',
      createdAt: Timestamp.fromMillis(now - 5 * 60 * 1000),
      isDeleted: false,
      messageType: 'text',
      readBy: ['local-cam'],
    }),
  ]);
}

async function seedRelationshipCards() {
  await db.collection('relationship_cards').doc('local-cam-card-1').set({
    ownerUid: 'local-cam',
    label: 'Long-term partner',
    connectionType: 'romantic_partner',
    displayNameOptional: '',
    status: 'active',
    note: 'Local-only relationship card used to exercise Circle privacy.',
    visibility: 'unnamed_public',
    sortOrder: 0,
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function resetDiscoverFixtureState() {
  const ownerUid = 'local-cam';
  const selectedUids = new Set(selectedDiscoverPeople.map((person) => person.uid));
  const allCandidateUids = allDiscoverPeople.map((person) => person.uid);
  const batch = db.batch();

  for (const candidateUid of allCandidateUids) {
    const pair = [ownerUid, candidateUid].sort().join('_');
    batch.delete(db.collection('profile_passes').doc(`${ownerUid}_${candidateUid}`));
    batch.delete(db.collection('likes').doc(`${ownerUid}_${candidateUid}`));
    batch.delete(db.collection('likes').doc(`${candidateUid}_${ownerUid}`));
    batch.delete(db.collection('matches').doc(pair));
    batch.delete(db.collection('conversations').doc(pair));
    batch.delete(db.collection('blocks').doc(`${ownerUid}_${candidateUid}`));
    batch.delete(db.collection('blocks').doc(`${candidateUid}_${ownerUid}`));

    if (!selectedUids.has(candidateUid) && candidateUid.startsWith('local-discover-')) {
      batch.delete(db.collection('profiles').doc(candidateUid));
      batch.delete(db.collection('users').doc(candidateUid));
    }
    batch.delete(db.collection('member_locations').doc(candidateUid));
  }

  batch.delete(db.collection('member_locations').doc(ownerUid));
  batch.delete(db.collection('_discover_sessions').doc(ownerUid));
  for (const action of ['discover', 'discover_location', 'like', 'pass']) {
    batch.delete(db.collection('_rate_limits').doc(`${action}_${ownerUid}`));
  }
  await batch.commit();

  const messageSnapshots = await Promise.all(
    allCandidateUids.map((candidateUid) => {
      const pair = [ownerUid, candidateUid].sort().join('_');
      return db.collection('messages').where('conversationId', '==', pair).get();
    }),
  );
  const messageBatch = db.batch();
  for (const snapshot of messageSnapshots) {
    for (const document of snapshot.docs) messageBatch.delete(document.ref);
  }
  await messageBatch.commit();

  for (const person of discoverStressPeople) {
    if (selectedUids.has(person.uid)) continue;
    try {
      await auth.deleteUser(person.uid);
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') throw error;
    }
  }
}

async function main() {
  await resetDiscoverFixtureState();
  for (const person of seededPeople) await seedPerson(person);
  await seedDiscoverLocations();
  await seedDiscoverPhotos();
  await seedExistingConnection();
  await seedRelationshipCards();

  console.log(`Seeded Polycircle Firebase emulators only for project ${projectId}.`);
  console.log('Member login: cam@local.polycircle.test');
  console.log('Moderator login: moderator@local.polycircle.test');
  console.log(`Local-only password: ${password}`);
  console.log(
    `Discover fixtures (${discoverFixtureCount}): ${selectedDiscoverPeople.map((person) => person.displayName).join(', ')}.`,
  );
  console.log(
    `Discover distances (miles): ${discoverFixtureDistancesMiles.slice(0, discoverFixtureCount).join(', ')}.`,
  );
  console.log(`Discover fixture radius: ${discoverFixtureRadius} miles.`);
  console.log(
    `Discover protected portrait fixtures: ${discoverFixtureCount} fictional emulator-only photos.`,
  );
  console.log('Existing connection: Jordan.');
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
