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

## Frontend integration (implemented on this branch)
1. The Reporte Médico page keeps its existing CSS, typography, colors, period selector, summary cards, caregiver grouping, daily detail table, navigation and PDF print behavior.
2. It now reads the five medical tables from the commercial Supabase project for the signed-in household.
3. Structured medical records appear in matching card/table styling below the existing daily-care detail.
4. The page checks for an owner session and an enabled `medico` app entitlement before loading the report.
5. Medical table queries are household-scoped and capped at the latest 500 rows per table; the date selector filters the loaded records locally.
6. Legacy medication free text is still shown only as a caregiver-reported observation. Structured medication status is shown only from explicit `medication_records` rows.
7. The existing daily-care report link and Historial navigation remain unchanged.
8. No historical caregiver reports are automatically backfilled into the medical tables.

## Important remaining checks before merge/deploy
- Confirm whether caregivers should eventually be permitted to insert medical observations through a secure caregiver workflow. Current policies intentionally reserve writes to household owners.
- Confirm the app entitlement key used by `has_app_access` and ensure Reporte Médico is included in the household's app catalog/access records.
- Add and test storage policies if examination documents are uploaded; `storage_path` is only a reference field at this stage.
- Test RLS using two separate households and both owner/member roles.
- Validate migration against a disposable/staging Supabase project, then run Supabase security advisors.
- Confirm current deployed source/hosting mapping before any production release.

## Current status
- SQL migration draft is committed to `feature/medical-records-foundation`.
- Reporte Médico frontend integration is committed to the same branch.
- The migration enables RLS, grants authenticated access subject to RLS, and checks both active subscription and the explicit `medico` app entitlement.
- No database migration has been applied.
- No production deployment has been made.
