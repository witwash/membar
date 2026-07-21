# Cocktail Study & Manager App: Implementation Plan

## Goal Description
Create a Flutter-based hobby app that allows the user to manage a personal directory of cocktails (CRUD operations) and test their knowledge of the ingredients and processes using interactive quizzes. The app will feature a local-first architecture with cloud syncing, built using functional programming principles and a modern, premium UI.

## Technology Stack
*   **Framework:** Flutter (targeting iOS and Android)
*   **State Management:** BLoC (Business Logic Component)
*   **Paradigm:** Functional programming using the `fpdart` package.
*   **UI Components:** `forui` package for a sleek, responsive design.
*   **Logging:** `talker` package for robust debugging.
*   **Data Storage:** Local persistence via `Hive`, cloud sync via Firebase.

---

## Finalized Specifications

### 1. Cocktail Data Model
The core domain entity `Cocktail` will track the following details:
*   **Name** (String)
*   **Ingredients** (List of objects containing: Item Name, Quantity, Unit)
*   **Process Steps** (List of Strings for instructions)
*   **Glassware** (String/Enum)
*   **Garnish** (String)
*   **Tags/Categories** (List of Strings, e.g., "Classic", "Tiki", "Gin")
*   **Image** (String path/URL)

### 2. Quiz & Study Mechanics
The app will feature interactive, dynamic testing based on the saved library. The initial scope includes:
*   **Matching Tests:** Matching ingredients to quantities, or garnishes to cocktails.
*   **Flashcards:** Self-assessed flip cards for quick studying of ingredients or steps.
*   **Multiple-Choice:** Dynamic questions (e.g., "Which of these ingredients belongs in a Negroni?").

### 3. App Structure & Navigation
A main bottom navigation bar will guide the user through three core sections:
*   **Library:** A master list of all cocktails. Supports searching, filtering by tags, and full CRUD operations (add new, edit existing, delete).
*   **Quiz/Study:** The hub to configure a study session (e.g., selecting all cocktails or a specific tag) and launch the interactive tests.
*   **Settings:** Preferences and Firebase account management for cloud syncing.

---

## Proposed Architecture

We will follow a clean architecture layered approach, leveraging `fpdart` for error handling (using `Either`) and data immutability.

### Presentation Layer (UI)
*   **Pages:** `LibraryPage`, `CocktailDetailsPage`, `CocktailEditorPage`, `QuizSetupPage`, `ActiveQuizPage`, `SettingsPage`.
*   **Widgets:** Custom widgets built on top of `forui` components to ensure a premium look.

### Application Layer (BLoC)
*   `LibraryBloc`: Manages the state of the cocktail list (loading, loaded, error) and handles CRUD events.
*   `QuizBloc`: Manages the state of an active study session (current question, score, user answers).
*   `SyncBloc`: Handles background synchronization between local Hive and Firebase.

### Domain Layer
*   `Cocktail` entity and `Ingredient` value objects (immutable data classes generated using the `freezed` package for robust equality, pattern matching, and copy mechanisms).
*   `ICocktailRepository`: Interface defining CRUD and sync operations returning `TaskEither` from `fpdart`.

### Data Layer
*   `LocalCocktailDataSource`: Implementation using Hive.
*   `RemoteCocktailDataSource`: Implementation using Firebase Firestore.
*   `CocktailRepositoryImpl`: Coordinates between local and remote sources, ensuring offline-first availability.

### Proposed Folder Structure (Clean Architecture)
```text
lib/
├── core/                   # Shared utilities, routing, errors, theme
│   ├── errors/             # Failure classes (for fpdart)
│   ├── router/             # GoRouter configuration
│   └── theme/              # forui theme configurations
├── features/               # Feature-based clean architecture
│   ├── library/            # The Cocktail Library feature
│   │   ├── domain/         # Entities, Repository Interfaces, Use Cases
│   │   ├── data/           # Models (DTOs), Repository Impls, Data Sources
│   │   └── presentation/   # BLoCs, Pages, Widgets
│   ├── quiz/               # The Study/Quiz feature
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   └── settings/           # Settings & Sync feature
│       ├── domain/
│       ├── data/
│       └── presentation/
└── main.dart               # Entry point and dependency injection setup
```

## User Review Required
The specification is now complete! Since you mentioned you didn't want any code written yet and just wanted to steer the spec, **please review this final document.**

If you are satisfied with this plan, let me know, and we can discuss the next steps (e.g., initializing the Flutter project, setting up Firebase, or building out the domain models).
