# Polycircle Dependency Security

Dependency health is part of release security. An install warning is not automatically exploitable, but high/critical production advisories must not be ignored because a build happens to pass.

## Automated check

`.github/workflows/dependency-audit.yml` installs the Functions dependency graph without executing package install scripts and runs:

```bash
npm audit --omit=dev --audit-level=high
```

This intentionally gates on **production** dependencies at high/critical severity. Development-only tooling advisories are still reviewed, but they are separated from code that ships into the Functions runtime so a noisy dev-tool advisory does not encourage unsafe `npm audit fix --force` changes.

## Update rules

- Do not run `npm audit fix --force` blindly.
- Read the advisory and affected dependency path.
- Prefer direct dependency upgrades that stay within supported Firebase/Node/Flutter compatibility.
- For transitive issues, verify whether the vulnerable code is reachable in the deployed runtime.
- Rebuild Functions, load the compiled module, run backend behavior tests, contracts, and Firebase security tests after dependency changes.
- Re-run emulator/manual acceptance for security-sensitive SDK upgrades.

## Lockfiles

The repository currently does not intentionally rely on committed npm lockfiles for the Functions/security-test packages, so CI and preflight use `npm install`, not `npm ci`.

Before external beta, decide and standardize the lockfile policy. Reproducible production builds normally benefit from reviewed lockfiles; adding them should be a deliberate dependency-baseline change, followed by CI and vulnerability review.

## Flutter packages

Before external beta:

- review outdated direct Flutter packages;
- review security advisories affecting native Firebase/Flutter dependencies;
- test iOS and Android after major Firebase plugin upgrades;
- do not update packages solely to chase newest versions when the new version breaks supported platform/runtime constraints.

## Release gate

No unresolved known high/critical **production-reachable** dependency vulnerability should be accepted for external beta without a documented impact analysis, mitigation, owner, and remediation date.
