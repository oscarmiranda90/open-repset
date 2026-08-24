# RepSet maintainer rules

Before changing product infrastructure, monetization, catalogue delivery, or
release configuration, read [OPEN_SOURCE_OPERATING_MODEL.md](OPEN_SOURCE_OPERATING_MODEL.md)
and [MEDIA_NOTICE.md](MEDIA_NOTICE.md). These rules apply to every agent and
contributor.

- The future public `repset` repository is the canonical home of shared app
  code. Do not create or maintain a second active Flutter codebase.
- Never add a default RepSet production catalogue/media URL to public source.
  Community builds use demo data unless their maintainer configures their own
  authorized source.
- Gym Visual GIFs are third-party media, not open source. Do not package,
  mirror, rehost, relicence, or make acquisition scripts for them.
- Never commit or expose API secrets, R2 write credentials, signing keys,
  RevenueCat secret keys, AI provider keys, deployment tokens, or personal
  data. Dart defines are public client configuration, not secret storage.
- Keep workout data local-first. Do not add user-data upload or sync without
  explicit approval, a privacy review, and an implemented deletion policy.
- All paid digital functionality uses the store-compliant purchase path; the
  server, not the client, authorizes any paid AI usage.
- Do not run official deployment commands from untrusted forks or pull
  requests. Protected CI is the only release path.
