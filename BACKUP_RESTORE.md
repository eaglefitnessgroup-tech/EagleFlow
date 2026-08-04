# EagleFlow Backup & Restore Procedures

EagleFlow includes a robust, offline-first local backup system designed to safeguard critical business data while strictly excluding sensitive secrets.

## Backup Procedure
1. Navigate to the **Settings** menu within EagleFlow (Admin only).
2. Select **Create Backup**.
3. The system exports a versioned, checksum-protected JSON file.
4. **Data Included:** App users (profiles), products, stock movements, quotations, and quotation line items.
5. **Data Excluded:** Password hashes, session tokens, Supabase keys, image caches, and pending sync queues are explicitly stripped.

## Restore Procedure
**WARNING**: A restore operation performs an atomic, all-or-nothing overwrite of local data. Existing records are updated; missing records are skipped safely.

1. Navigate to the **Settings** menu.
2. Select **Restore from Backup**.
3. The system performs a dry-run check:
   - Verifies the integrity of the JSON schema.
   - Validates the SHA-256 checksum.
4. An automatic pre-restore backup is generated locally.
5. If dry-run passes, the system atomically commits the restored records.
6. Local user secrets (e.g., existing password hashes) are strictly preserved and never overwritten by the restore payload.

## Disaster Recovery / Migration
If the application is reinstalled on a new device:
1. Log in using an Admin account (requires initial internet connection).
2. Transfer the `.json` backup file to the device.
3. Execute the Restore Procedure.
4. Sync the data up to the Supabase remote (if internet is available).
