# Flutter Task Manager

A Flutter conversion of the React Task Manager app.

## Features

- ✅ Add, edit, and delete tasks
- ✅ Mark tasks as complete (with strikethrough)
- ✅ Due dates with color-coded labels (Overdue / Today / Tomorrow)
- ✅ Progress bar showing completion ratio
- ✅ Sort by due date or creation date
- ✅ Dark / light theme toggle
- ✅ Persistent storage via `shared_preferences`

## Project Structure

```
lib/
├── main.dart                      # App entry point & theming
├── models/
│   └── task.dart                  # Task data model + JSON serialization
├── providers/
│   └── task_provider.dart         # State management (ChangeNotifier)
├── screens/
│   └── home_screen.dart           # Main screen
└── widgets/
    ├── task_card.dart             # Individual task row
    ├── task_form_dialog.dart      # Add / edit dialog
    └── delete_confirm_dialog.dart # Delete confirmation dialog
```

## Getting Started

```bash
flutter pub get
flutter run
```

Requires Flutter 3.10+ and Dart 3.0+.
