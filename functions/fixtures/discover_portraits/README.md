# Local Discover portrait fixtures

These portraits are fictional, AI-generated test assets for the guarded
Firebase emulator seed only. They do not depict Polycircle members, founders,
or other known people, and production code does not reference them.

`functions/scripts/seed_emulator.cjs` uploads the selected fixture count to the
local Storage emulator and creates matching server-owned `profile_media`
records. The app still retrieves every image through the existing protected
profile-media callable. The seed refuses to run unless Auth, Firestore, and
Storage hosts are loopback emulators.

Generated with the built-in Codex image-generation tool on 2026-08-18 as two
natural editorial portrait contact sheets, then cropped to 384×384 JPEGs for
local visual testing.
