# EagleFlow Deployment Guide

## Overview
EagleFlow is designed to be deployed primarily as an Android Application and a Windows Desktop Application. It connects to a Supabase backend for real-time synchronization, but is fully capable of operating in an offline-first local mode using Sembast.

## Infrastructure Setup (Supabase)
1. **Create Project**: Set up a new project in Supabase.
2. **Schema Migration**: Run the Phase 7 database migration script (`eagleflow_phase7_migration_001.sql`) in the Supabase SQL editor.
3. **Authentication**: Enable Email/Password authentication. Ensure RLS (Row Level Security) policies are properly enforced.
4. **Environment Variables**: Note down the `Project URL` and `anon public` key.

## App Deployment

### Android
1. **Keystore Generation**: Create a robust release keystore. Keep the `.jks` file secure.
2. **`key.properties`**: Create `android/key.properties` containing the store password, key password, key alias, and store file path.
3. **Build Command**:
   ```bash
   flutter build appbundle --release --dart-define=SUPABASE_URL=YOUR_PROD_URL --dart-define=SUPABASE_ANON_KEY=YOUR_PROD_KEY
   ```
4. **Distribution**: Upload the resulting `.aab` file to the Google Play Console or distribute the `.apk` directly to internal devices.

### Windows
1. **Signing**: Use a valid Authenticode certificate to sign the Windows executable.
2. **Build Command**:
   ```bash
   flutter build windows --release --dart-define=SUPABASE_URL=YOUR_PROD_URL --dart-define=SUPABASE_ANON_KEY=YOUR_PROD_KEY
   ```
3. **Distribution**: Package the `build\windows\runner\Release` folder into an installer (e.g., using Inno Setup or MSIX) for secure distribution.

## Post-Deployment Validation (Smoke-test Checklist)
- [ ] Login screen prevents access without internet on first-ever launch?
- [ ] Offline persistence works across app restarts?
- [ ] Sync queue flushes smoothly when internet is restored?
- [ ] Admin restrictions prevent Salespersons from accessing stock adjustments?
