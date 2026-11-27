<div align="center">

# ListNote 📝

**Capture ideas. Organize notes. Get things done.**

A modern notes and task management app built with **Flutter**, **Firebase Authentication**, and **Cloud Firestore**, featuring an Elegant Blue mobile interface.

[![Flutter](https://img.shields.io/badge/Flutter-Mobile-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-Language-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
![Status](https://img.shields.io/badge/Status-Active%20Development-64748B)

[**Explore the Figma Design**](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=4-73) · [**Source Code**](https://github.com/KahfiFauzan/ListNote) · [**Author**](https://github.com/KahfiFauzan)

</div>

---

## ✨ About the Project

**ListNote** brings personal notes and daily tasks into a single, distraction-free workspace. Designed with a soft blue-and-white visual language, it provides a simple way to capture ideas, categorize notes, and track progress on tasks.

This project combines **UI/UX design in Figma** with a **Flutter Android implementation** connected to Firebase. The current repository is a development build, not an app-store release.

## 🎨 UI/UX Design — Figma

Explore the original ListNote mobile designs:

| Screen | Android design | iPhone design |
|:--|:--|:--|
| **Main UI collection** | [Explore all screens ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=4-73) | [Explore all screens ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=4-73) |
| **Login** | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-33) | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-8) |
| **Register** | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-84) | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-58) |
| **Reset password** | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-130) | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-110) |
| **Account settings** | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-179) | [View frame ↗](https://www.figma.com/design/dSy40mtFNZy8ECXsa17n3A/LISTNOTE?node-id=12-150) |

> **Design preview:** These links open the actual Figma frames. Raster previews are not embedded yet. Figma represents the UI design; the latest implementation may include newer task and category features not shown in older frames.

## 🚀 Features

### 🗒️ Notes
- Create and edit personal notes.
- Pin important notes for quick access.
- Search and filter notes.
- Create and manage custom note categories.

### ✅ To-Do List
- Add, edit, and delete tasks.
- Organize tasks with custom categories.
- Track **Pending (−)**, **Completed (✓)**, and **Cancelled (✕)** states.
- See task progress on the home dashboard.

### ☁️ Authentication & Storage
- Email/password account registration and login.
- Password reset via Firebase Authentication.
- Realtime data synchronization with Cloud Firestore.
- Per-account notes, tasks, and categories.
- Profile name editing and logout.

> **Google Sign-In:** The integration is included in the code, but full end-to-end verification is still pending.

## 🛠️ Tech Stack

| Technology | Usage |
|:--|:--|
| **Flutter & Dart** | Mobile UI and application logic |
| **Material Design 3** | Interface and navigation components |
| **Firebase Authentication** | User sign-in and account management |
| **Cloud Firestore** | Cloud database and realtime updates |
| **FlutterFire** | Firebase platform configuration |
| **Figma** | UI/UX design for Android and iPhone |

## 📂 Project Structure

```text
lib/
├── main.dart             # Auth, dashboard, notes and settings
├── todo_page.dart        # Tasks and task categories
└── firebase_options.dart # Firebase client configuration
android/
ios/
pubspec.yaml
```

## ⚙️ Getting Started

**Requirements:** Flutter SDK, Android SDK, an emulator or Android phone, and your own Firebase project with Authentication and Firestore enabled.

1. Clone and install packages:

   ```bash
   git clone https://github.com/KahfiFauzan/ListNote.git
   cd ListNote
   flutter pub get
   ```

2. Set up Firebase in your own project:

   ```bash
   flutterfire configure
   ```

   Enable **Email/Password** in Firebase Authentication and set up Cloud Firestore security rules. Provide your Android client configuration (`android/app/google-services.json`) as required by the Firebase/Google services setup.

3. Run on an Android device:

   ```bash
   flutter devices
   flutter run
   ```

### Firestore Data Layout

```text
users/{uid}
├── notes/{noteId}
├── tasks/{taskId}
├── categories/{categoryId}
└── note_categories/{categoryId}
```

**Security:** Restrict each user's Firestore data to their authenticated UID using Firestore Security Rules. Never commit administrator credentials, service account files, passwords or private signing keys.

## 📌 Development Status

| Component | Status |
|:--|:--|
| Android debug build (Samsung Galaxy S23) | ✅ Built and launched |
| Email/password authentication | ✅ Tested |
| Notes, tasks, status and category flows | 🧪 Implemented; full regression testing recommended |
| Google Sign-In | 🧪 OAuth verification pending |
| iOS | 📱 Designed; build not yet tested |
| App-store distribution | ⏳ Not released |

## 🗺️ Roadmap

- [ ] Verify task status and category operations after app restarts.
- [ ] Complete Google Sign-In verification.
- [ ] Add exported Figma screenshots and an app demonstration.
- [ ] Add automated testing and release checks.
- [ ] Test and prepare signed Android and iOS builds.

## 👨‍💻 Author

**Kahfi Fauzan Habibi**

[GitHub — @KahfiFauzan](https://github.com/KahfiFauzan) · [Email](mailto:fauzankahfi28@gmail.com)

---

<div align="center"><sub>Designed with Figma · Built with Flutter & Firebase 💙</sub></div>
