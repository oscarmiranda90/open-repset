# Security and privacy

RepSet is designed to keep workout data on the device. The app does not offer
user file uploads, photo uploads, document uploads, or a way to submit
personal health records.

## Data boundary

- Workout sessions are stored locally in SQLite.
- A configured static catalogue may supply shared exercise metadata. Community
  builds use the local demo catalogue unless their maintainer configures an
  authorized source.
- The app must never add an upload or sync feature for user-generated files or
  sensitive personal data without a separate privacy review, consent flow,
  retention policy, and server-side access controls.

## Repository safety

Do not commit service-account files, certificates, signing keys, `.env` files,
`.dev.vars`, Wrangler state, database exports, or real user data. The
repository's safety check blocks common secret filenames and credential
patterns.

Removing a secret from the latest commit does not remove it from Git history.
If a credential was ever pushed, rotate it and rewrite the affected history
before making the repository public.

Before opening a pull request, run:

```bash
./scripts/check-public-repo.sh
flutter test
```

If you believe you found a vulnerability, do not open a public issue. Contact
the maintainer privately with a minimal reproduction and avoid including any
personal data or credentials.
