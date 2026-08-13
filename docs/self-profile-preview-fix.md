Self-profile preview fix plan

1. Treat an explicit ownerUid request as member-facing protected photo delivery, including when the requester owns the profile.
2. Reuse ProfileDetailScreen for View My Profile with member actions disabled.
3. Keep photo URLs short-lived and never store them in profile documents.
4. Show approved photos inline to the owner instead of only as status rows.
5. Add regression coverage for owner preview and protected delivery.
