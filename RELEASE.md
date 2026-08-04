# EagleFlow Release Procedure

This document outlines the standard release procedure for EagleFlow v1.0 and beyond.

## Pre-Release Checklist
1. **Version Update**: Update `version: 1.0.0+1` in `pubspec.yaml` using standard Semantic Versioning.
2. **Environment Verification**: Ensure `SUPABASE_URL` and `SUPABASE_ANON_KEY` are strictly production keys, securely injected at build time via `--dart-define`.
3. **Tests**: Run `flutter test` and confirm 100% pass rate.
4. **Analyzer**: Run `flutter analyze` and confirm no critical or high severity issues.
5. **Assets**: Confirm splash screens, launcher icons, and branding materials are correctly sized and linked.

## Build Commands
**Android:**
```bash
flutter build apk --release --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
flutter build appbundle --release --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

**Windows:**
```bash
flutter build windows --release --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

## Rollback Checklist
If a critical flaw is discovered post-release:
1. Revert to the previous known stable commit using `git checkout`.
2. Increment the patch version (e.g., `1.0.0+1` -> `1.0.1+2`).
3. Rebuild and distribute the hotfix immediately.
4. Notify active users to force an update.
