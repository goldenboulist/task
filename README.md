# Task Manager

![App Logo](assets/image.png)

A modern, cross-platform task management application built with Flutter. This app provides a clean and intuitive interface for managing daily tasks with features like due date tracking, progress monitoring, and persistent data storage.

## Features

- **Task Management**: Add, edit, and delete tasks with ease
- **Completion Tracking**: Mark tasks as complete with visual strikethrough indication
- **Due Date Management**: Color-coded labels for overdue, today, and tomorrow tasks
- **Progress Visualization**: Real-time progress bar showing task completion ratio
- **Flexible Sorting**: Sort tasks by due date or creation date
- **Theme Support**: Toggle between dark and light themes for comfortable usage
- **Data Persistence**: Reliable local storage using SQLite database
- **Cross-Platform**: Runs on Android, iOS, Windows, macOS, and Linux

## Technical Architecture

### Project Structure

```
lib/
├── main.dart                      # Application entry point and theming
├── models/
│   └── task.dart                  # Task data model with JSON serialization
├── providers/
│   └── task_provider.dart         # State management using Provider pattern
├── screens/
│   └── home_screen.dart           # Main application interface
└── widgets/
    ├── task_card.dart             # Individual task display component
    ├── task_form_dialog.dart      # Add/edit task dialog
    └── delete_confirm_dialog.dart # Delete confirmation dialog
```

### Technology Stack

- **Framework**: Flutter 3.10+ with Material 3 design
- **Language**: Dart 3.0+
- **State Management**: Provider pattern with ChangeNotifier
- **Database**: SQLite with sqflite package
- **Storage**: Persistent local storage with cross-platform support
- **Notifications**: Local notifications support
- **Connectivity**: Network status monitoring

## Installation & Setup

### Prerequisites

- Flutter SDK 3.10 or higher
- Dart SDK 3.0 or higher
- Android Studio / VS Code with Flutter extensions
- Platform-specific development tools (Xcode for iOS, Android SDK for Android)

### Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd task
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Set up Android SDK and emulator
- Ensure `android` platform is added: `flutter config --enable-android`

#### iOS
- Requires macOS with Xcode installed
- Ensure `ios` platform is added: `flutter config --enable-ios`

#### Desktop (Windows, macOS, Linux)
- Desktop platforms are automatically supported
- Additional setup may be required for specific platforms

## Usage

### Creating Tasks
- Tap the add button to create a new task
- Enter task title, description, and due date
- Save to add the task to your list

### Managing Tasks
- **Complete**: Check the checkbox to mark tasks as complete
- **Edit**: Long-press or tap edit to modify task details
- **Delete**: Use the delete option with confirmation dialog

### Organization Features
- **Sorting**: Use sort options to organize by due date or creation date
- **Filtering**: View all tasks, active tasks, or completed tasks
- **Progress**: Monitor overall completion progress with the progress bar

### Personalization
- **Themes**: Switch between light and dark themes
- **Preferences**: Settings are automatically saved and restored

## Development

### Key Dependencies

- `provider: ^6.1.2` - State management
- `sqflite: ^2.3.3` - SQLite database
- `shared_preferences: ^2.3.2` - Local preferences storage
- `uuid: ^4.4.0` - Unique identifier generation
- `intl: ^0.19.0` - Internationalization and date formatting
- `flutter_local_notifications: ^18.0.0` - Local notifications
- `connectivity_plus: ^6.0.3` - Network connectivity monitoring

### Database Schema

The application uses SQLite with the following task structure:
- `id`: Unique identifier (UUID)
- `title`: Task title
- `description`: Task description (optional)
- `dueDate`: Due date timestamp
- `isCompleted`: Completion status
- `createdAt`: Creation timestamp
- `updatedAt`: Last modification timestamp

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a pull request

### Code Style

This project follows Flutter/Dart official style guidelines and uses:
- `flutter_lints: ^3.0.0` for static analysis
- Material 3 design system
- Provider pattern for state management
- Clean architecture principles

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, questions, or contributions, please:
- Open an issue on GitHub
- Review existing issues before creating new ones
- Provide detailed information about bugs or feature requests

---

Built with using Flutter
