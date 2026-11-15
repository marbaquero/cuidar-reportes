# Medical records foundation — implementation notes

## Scope
This branch adds a separate, household-scoped medical record model for the existing Reporte Médico experience. It does not replace or alter `care_reports`, the daily caregiver form, Historial, or any of the other six apps.

## Data model
- `medical_events`: symptoms, incidents, diagnoses and other health events.
- `medical_measurements`: typed observations, including structured systolic/diastolic blood pressure.
- `medication_records`: explicit administered / missed / refused / held / unknown statuses.
- `medical_appointments`: appointment details, clinician, outcome and follow-up date.
- `medical_examinations`: examination date/type, provider, summary and optional Storage path.

Every record belongs to a `household_id`. RLS is enabled. Household members can read records in their own household; household owners with app access can create, update and delete. The existing household helper functions are reused, matching the current `care_reports` authorization pattern.

## Frontend integration plan (not yet implemented)
1. Keep the current Reporte Médico HTML/CSS unchanged as the visual baseline.
2. Add a data-access layer that reads the five medical tables for the signed-in household.
3. Preserve the current period selector, summary cards, caregiver grouping, table, and PDF export.
4. Clearly label legacy daily-care observations separately from structured medical records.
5. Do not infer medication adherence from free-text `care_reports.medicacion`. Show a medication status only when an explicit `medication_records.status` row exists.
6. Keep the existing daily-care report link and Historial navigation.
7. Do not backfill or migrate historical caregiver reports automatically. Any later import must be reviewed field-by-field and retain provenance as legacy caregiver observations.

## Important remaining checks before merge/deploy
- Confirm whether caregivers should eventually be permitted to insert medical observations through a secure caregiver workflow. Current policies intentionally reserve writes to household owners.
- Confirm the app entitlement key used by `has_app_access` and ensure Reporte Médico is included in the household's app catalog/access records.
- Add and test storage policies if examination documents are uploaded; `storage_path` is only a reference field at this stage.
- Test RLS using two separate households and both owner/member roles.
- Validate migration against a disposable/staging Supabase project, then run Supabase security advisors.
- Confirm current deployed source/hosting mapping before any production release.

## Current status
- SQL migration draft is committed to `feature/medical-records-foundation`.
- No database migration has been applied.
- No frontend files have been modified.
- No production deployment has been made.
