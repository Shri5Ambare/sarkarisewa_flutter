# Sarkari Sewa / UniHub Flutter Application

Welcome to the Flutter companion application for Sarkari Sewa/UniHub. This application provides a seamless mobile and web experience for our students, teachers, and admins to interact with courses, mock tests, news, and more.

## Features

- **Authentication**: Email/password authentication via Firebase Auth.
- **Roles**: Distinct role-based access for `admin`, `teacher`, and `student`.
- **Courses**: Browse, order, and activate courses.
- **Mock Tests**: Complete multi-question mock tests and track scores.
- **SS Coins**: Virtual wallet to spend on courses or test entries.
- **Admin Dashboard**: Real-time stats, order activation, user management, and marketing tools.

## Prerequisites

- **Flutter SDK**: Ensure you have Flutter installed (tested against recent stable versions).
- **Firebase**: The project relies on Firebase (Auth, Firestore, FCM). Ensure your `firebase_options.dart` is correctly configured for your environment.

## Getting Started

1. **Install Dependencies:**

   ```bash
   flutter pub get
   ```

2. **Run the App:**
   - Web: `flutter run -d web-server --web-port 8080` (or `chrome`)
   - Android/iOS/Windows: `flutter run`

## Secure Build Targets

This repository enforces separate entry points for client and admin builds:

- Client/mobile builds must use `lib/main.dart`
- Admin web builds must use `lib/main_admin_web.dart`

Guarded scripts:

```powershell
pwsh -File .\scripts\build_client_apk.ps1
pwsh -File .\scripts\build_admin_web.ps1
```

CI workflow `.github/workflows/build-target-guard.yml` verifies target rules and fails if a wrong target is used for a profile.

## Data Seeding & Automated Testing

To quickly test the end-to-end functionality of the platform, an automated script is provided. The script will:

- Sign in as Admin.
- Create a test course and mock test.
- Elevate a test user to `gold` tier.
- Sign in as the Student.
- Order the newly created course.
- Sign in as Admin again and approve the order.

To run the automated E2E script visually:

```bash
flutter run -d chrome -t lib/e2e_test.dart
```

This ensures the Firestore rules, models, and workflows are operating correctly.

## Architecture

- **State Management**: `provider` pattern for Auth and Locale state.
- **Database**: Firebase Cloud Firestore with centralized queries via `FirestoreService`.
- **Routing**: Functional declarative routing via `go_router`.

## Development Notes

- **UI Guidelines**: Components heavily rely on the predefined `AppColors` palette in `theme.dart`.
- **Localization**: UI text maps through `l10n/strings.dart`. Ensure strings are added before deploying new views.
