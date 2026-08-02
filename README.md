# eagleflow

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Development Setup: Local Persistence (Web)

When running EagleFlow locally on the web (Chrome), the app uses **IndexedDB** for local storage. 
Because IndexedDB is strictly tied to the application's origin (protocol + domain + port), **changing the localhost port creates a separate IndexedDB database**. Products or quotations created on one port will not be visible on another port, and the app will appear to have reset its data (and may reseed sample products if empty).

To prevent this data loss during development, **always use the same port**.

**Required Run Command:**
```bash
flutter run -d chrome --web-port=8080
```

*(Note: If you use VSCode, a `.vscode/launch.json` has been provided which automatically applies this port configuration when you launch the app.)*
