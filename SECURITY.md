# Security Policy

## Supported versions

Only the latest release gets security fixes. This is a small, solo-maintained project, not
something with a long-term support matrix.

| Version | Supported |
| ------- | --------- |
| 1.3.0   | Yes       |
| < 1.3.0 | No        |

## Reporting a vulnerability

Please don't open a public issue for a security problem. Use GitHub's private reporting
instead: go to the "Security" tab on this repo, then "Report a vulnerability." That opens a
private advisory only the maintainer can see until it's resolved.

If you'd rather not use GitHub, open a regular issue asking to be contacted privately and I'll
follow up.

I'll acknowledge reports within a few days and aim to have a fix or a clear timeline within two
weeks, but this is a spare-time project, so please be patient. Once a fix ships, I'll credit the
report (unless you'd rather stay anonymous) in the release notes.

## Scope

Tossy is a local macOS app: it doesn't run a server and doesn't upload anything anywhere.
The realistic attack surface is mostly around parsing untrusted files (a malicious image, video,
or audio file someone converts) triggering a bug in the app itself or in one of the bundled
tools.

In scope:
- The app's own Swift code (`Sources/`)
- How the app invokes the bundled `ffmpeg`, `cwebp`/`dwebp`, and `cjxl`/`djxl` binaries (argument
  handling, temp file handling, and similar)

Out of scope, but still worth reporting so the vendored version can be updated:
- Vulnerabilities inside `ffmpeg`, `cwebp`/`dwebp`, or `cjxl`/`djxl` themselves. Those are
  upstream projects; the real fix has to land there first. See `Vendor/*/LICENSE_NOTICE.md` and
  `Vendor/*/LICENSE` for what's bundled and which version.

## What's not a vulnerability

Formats that report as "unavailable" (this build's ffmpeg lacking an encoder for OGV or AMR, for
example) are a known limitation, not a security issue, unless you can show it's actually
exploitable rather than just missing.
