/**
 * Ops tooling — NOT shipped in the app and never run by CI.
 *
 * Grants or revokes the `moderator` custom claim that gates the
 * photo moderation surface (Safety Center -> Photo moderation) and
 * the moderation callables. This is the production claim-granting
 * path the QA-era codebase never had: the only other
 * setCustomUserClaims call in the repo is the emulator seed, which
 * refuses to run against real projects.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
 *     node functions/scripts/set_moderator_claim.cjs \
 *       --project <firebase-project-id> --uid <auth-uid> --grant
 *     # prints the intended change only (dry run by default)
 *   ... add --confirm to actually write.
 *
 * Safety guards:
 *   - --project and --uid are always explicit; there are no defaults
 *     that could silently target a project.
 *   - Exactly one of --grant / --revoke is required.
 *   - The write happens only with --confirm; anything else is a
 *     dry run that prints the account's claims before and the exact
 *     claims that would replace them.
 *   - Refuses to run while Firebase emulator hosts are set — this
 *     tool targets real projects; emulator fixtures belong to the
 *     seed.
 *   - Other existing claims are preserved: grant merges
 *     {moderator: true} into the current claims, revoke removes
 *     only the moderator key.
 *
 * Claims take effect on the account's next ID-token refresh
 * (sign-in, or the app's forced refresh when it opens the queue).
 * Revocation is therefore the kill switch for the moderation
 * surface: revoke, and the entry disappears and the callables deny
 * the refreshed token. See docs/moderation-runbook.md,
 * "Moderator claim operations".
 */
const {applicationDefault, initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');

function refuse(message) {
  console.error(`Refusing to change moderator claims: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    project: null,
    uid: null,
    grant: false,
    revoke: false,
    confirm: false,
    dryRun: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--project') {
      args.project = argv[i + 1] ?? null;
      i += 1;
    } else if (flag === '--uid') {
      args.uid = argv[i + 1] ?? null;
      i += 1;
    } else if (flag === '--grant') {
      args.grant = true;
    } else if (flag === '--revoke') {
      args.revoke = true;
    } else if (flag === '--confirm') {
      args.confirm = true;
    } else if (flag === '--dry-run') {
      args.dryRun = true;
    } else {
      refuse(`unknown argument "${flag}".`);
    }
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.project) {
    refuse('--project <firebase-project-id> is required (no default).');
  }
  if (!args.uid) {
    refuse('--uid <auth-uid> is required (no default).');
  }
  if (args.grant === args.revoke) {
    refuse('pass exactly one of --grant or --revoke.');
  }
  if (
    process.env.FIREBASE_AUTH_EMULATOR_HOST
    || process.env.FIRESTORE_EMULATOR_HOST
    || process.env.FIREBASE_STORAGE_EMULATOR_HOST
  ) {
    refuse(
      'Firebase emulator hosts are set. This tool targets real projects; '
      + 'unset the emulator hosts or use the emulator seed instead.',
    );
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: args.project,
  });
  const auth = getAuth();

  const user = await auth.getUser(args.uid);
  const before = user.customClaims ?? {};
  console.log(`Project: ${args.project}`);
  console.log(`Account: ${user.uid} <${user.email ?? 'no email'}>`);
  console.log(`Claims before: ${JSON.stringify(before)}`);

  const after = {...before};
  if (args.grant) {
    after.moderator = true;
  } else {
    delete after.moderator;
  }

  if (JSON.stringify(after) === JSON.stringify(before)) {
    console.log(
      args.grant
        ? 'No change: the account already holds the moderator claim.'
        : 'No change: the account does not hold the moderator claim.',
    );
    return;
  }
  console.log(`Claims after:  ${JSON.stringify(after)}`);

  if (args.dryRun || !args.confirm) {
    console.log('Dry run only — no change written. Re-run with --confirm to apply.');
    return;
  }

  await auth.setCustomUserClaims(args.uid, after);
  const updated = await auth.getUser(args.uid);
  console.log(`Claims written: ${JSON.stringify(updated.customClaims ?? {})}`);
  console.log(
    'The claim takes effect on the account\'s next ID-token refresh '
    + '(sign-in, or the forced refresh when the moderation queue opens).',
  );
}

main().catch((error) => {
  console.error(`Failed to change moderator claims: ${error.message}`);
  process.exit(1);
});
