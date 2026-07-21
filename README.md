# IHWE Attendance Control Centre

Separate Flutter application for admin-only event entry scanning and attendance intelligence.

## Run

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-backend.example.com/api
```

The default API URL is the deployed IHWE ngrok backend. Override it for another environment with `--dart-define=API_BASE_URL=https://your-backend.example.com/api`.

## App flow

1. Login with an existing IHWE admin username and password.
2. Dashboard shows registered, present, not-arrived and category/day totals.
3. Scan any existing IHWE visitor, buyer or exhibitor QR.
4. Review the resolved person, photo and complete contact/registration details.
5. Select one day, multiple days or all unmarked event days and confirm.
6. Review searchable attendance records from the Attendance tab.

The backend accepts all current QR payload variants: JSON payloads, registration-ID-only QR codes and visitor/buyer URL QR codes.

## Folder structure

```text
lib/
  core/
    config/       build-time environment configuration
    network/      authenticated API client and errors
    storage/      persistent admin session
    theme/        IHWE design system
  features/
    auth/         admin login repository and UI
    attendance/   attendance models and repository
    dashboard/    event intelligence and navigation shell
    scanner/      QR camera and person confirmation flow
    history/      searchable attendance records
```

## Backend endpoints

All routes require an admin JWT via `Authorization: Bearer <token>`.

- `GET /api/attendance/config`
- `POST /api/attendance/resolve`
- `POST /api/attendance/mark`
- `GET /api/attendance/dashboard`
- `GET /api/attendance/records`
- `DELETE /api/attendance/:id`

Attendance is idempotent: the unique event/day/person index prevents duplicate check-ins even if two admins scan the same QR simultaneously.
