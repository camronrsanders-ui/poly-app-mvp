const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {FieldValue, Timestamp, getFirestore} = require('firebase-admin/firestore');

const nativeFirebaseProjectId = 'poly-circle-j5v6dy';

function isLoopbackEmulatorHost(value) {
  if (typeof value !== 'string') return false;
  return /^(?:127\.0\.0\.1|localhost|\[?::1\]?):\d+$/.test(value.trim());
}

function requireEmulatorEnvironment() {
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!firestoreHost || !authHost) {
    throw new Error(
      'Refusing to seed: FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST must both be set.',
    );
  }
  if (!isLoopbackEmulatorHost(firestoreHost) || !isLoopbackEmulatorHost(authHost)) {
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
const password = 'LocalOnly123!';

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
    distanceRadius: 100,
    preferredStructures: [],
    preferredIntentions: [],
    profileVisibility: person.profileVisibility ?? 'public',
    mapVisibility: 'private',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
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

async function main() {
  for (const person of people) await seedPerson(person);
  await seedExistingConnection();
  await seedRelationshipCards();

  console.log(`Seeded Polycircle Firebase emulators only for project ${projectId}.`);
  console.log('Member login: cam@local.polycircle.test');
  console.log('Moderator login: moderator@local.polycircle.test');
  console.log(`Local-only password: ${password}`);
  console.log('Discover fixtures: Alex and Riley. Existing connection: Jordan.');
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});