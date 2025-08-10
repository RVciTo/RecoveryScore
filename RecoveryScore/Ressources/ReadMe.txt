# 📘 README.md — Athletica.OS

> **A modern SwiftUI-based athlete-centric iOS companion for training, recovery, nutrition, and AI-driven coaching.**

---

## ✨ Overview

**Athletica.OS** is a modular SwiftUI application integrating:

- 💡 Training Plan Management  
- 📈 Daily Readiness & Recovery Scoring  
- 🍽️ Macro/Micronutrition Analytics  
- 🧠 Self-Assessment Journal  
- 🤖 AI Coaching Overlay  
- 🔄 HealthKit-based Data Sync  

Everything is built with native SwiftUI, MVVM, and Combine—no storyboards or third-party UI frameworks.

---

## 🧱 Architectural Principles

| Layer          | Responsibility                                                                 |
|----------------|----------------------------------------------------------------------------------|
| **Views**      | SwiftUI UI definitions, bound to `ObservableObject` ViewModels.                 |
| **ViewModels** | Business logic, Combine data handling, navigation orchestration.                |
| **Models**     | Codable structs for workouts, nutrition, baselines, user profiles.              |
| **Services**   | Singletons for API (OpenAI) and HealthKit access.                               |
| **Mock**       | Preview and test-ready mock data sources.                                       |

---

## 📁 Folder Structure

```text
Athletica.OS/
├─ App.swift                        ⟵ App entry point & DI container
├─ Assets.xcassets/                ⟵ App icon, colors
├─ Core/                           ⟵ Shared network & system-level components
├─ Feature/                        ⟵ Domain modules: Workouts, Recovery, Nutrition, etc.
├─ TestSupport/                    ⟵ Mocks & stubs for Previews and UnitTests
├─ Athletica.OSTests/              ⟵ Algorithm & logic unit tests
├─ Athletica.OSUITests/           ⟵ UI navigation tests
└─ Athletica.OS.entitlements       ⟵ HealthKit, permissions


⸻

📦 Module Breakdown

🧠 Feature/Recovery
	•	ViewModels
	•	RecoveryBiometricsViewModel.swift: Manages biometric score states via HealthKit and readiness engine.
	•	RecoveryBiometricsSectionView.swift: Sectioned data aggregation for view rendering.
	•	Views
	•	RecoveryBiometricsView.swift: Table layout for displaying daily recovery metrics.
	•	ReadinessScoreCardView.swift: Summary view with color-coded readiness.
	•	ReadinessScoreExplanation.swift: Breakdown modal with Z-score components.

⸻

🏋️ Feature/Workouts
	•	ViewModels
	•	WorkoutListViewModel.swift: Fetches, filters, and computes perceived exertion.
	•	Views
	•	WorkoutListView.swift: Main view with user workouts.
	•	WorkoutRow.swift: Row view for each workout.
	•	WorkoutView.swift: Detailed workout view.
	•	WorkoutsCard.swift: Dashboard compact summary.
	•	PerceivedExertionExplanationView.swift: Formula explanation modal.
	•	Utils
	•	WorkoutActivityMetadata.swift: Core computation logic for exertion metrics.

⸻

📊 Feature/Common
	•	Views
	•	DashboardView.swift: 5-card home dashboard (Readiness, Nutrition, Workouts, Program, Self-Assessment).
	•	MainTabView.swift: Primary tab container (Dashboard, Coach, Program, Account).
	•	ScoreCardView.swift: Shared visual component for scores.
	•	ViewModels
	•	MainTabViewModel.swift: Manages navigation and tab state.

⸻

🗓️ Feature/Program
	•	ViewModels
	•	ProgramPlannerViewModel.swift: Weekly plan state, validation, and drag/drop logic.
	•	ProgramWeekListViewModel.swift: Controls expandable list of weeks.
	•	Views
	•	ProgramPlannerView.swift: Main calendar grid for session planning.
	•	ProgramWeekListView.swift: Expandable list of training weeks.
	•	ProgramWeekDetailView.swift: Inline-editable weekly schedule.
	•	ProgramCard.swift: Dashboard card for current week adherence.
	•	AdherenceScoreExplanationView.swift: Visual breakdown of adherence %.
	•	SessionCardView.swift: Compact display of individual sessions.

⸻

🧑 Feature/Users
	•	ViewModels
	•	AccountViewModel.swift: Holds and updates user profile data.
	•	Views
	•	AccountView.swift: Editable view for age, gender, units, goals.

⸻

💬 Feature/AIAssistant
	•	AIAssistantViewModel.swift (WIP): Controls AI input/output message logic (needs connection to AIAssistantService).
	•	AIAssistantView.swift (MISSING): View expected to provide overlay chat interface.

⸻

📉 Feature/SelfAssessment
	•	ViewModels
	•	(Missing or incomplete)
	•	Views
	•	SelfAssessmentView.swift: Picker interface for DOMS and mood (incomplete implementation).

⸻

🍽️ Feature/Nutrition
	•	ViewModels
	•	NutritionDetailViewModel.swift: Calculates weekly kcal and macro scores.
	•	Views
	•	NutritionDetailView.swift: Horizontal bar chart for daily intakes.

⸻

🔁 Core
	•	HTTPClientProtocol.swift: Dependency-injection–friendly interface for HTTP clients.
(Use this for injecting OpenAI / backend clients.)

⸻

🧪 TestSupport
	•	MockWorkoutData.swift, MockProgramData.swift, MockNutritionData.swift: Previews and test JSON.
	•	MockAIChatClient.swift: Placeholder for simulating AI responses.

⸻

📌 Outstanding Work

🔧 Functional Gaps
	•	AI Assistant
	•	View is missing
	•	ViewModel is present but not connected to backend or UI
	•	Self‑Assessment
	•	ViewModel is missing
	•	Scoring logic is absent
	•	User Profile / Persistence
	•	No database or file storage layer implemented
	•	Program Interaction
	•	Partially functional UI, not yet wired to persistent storage or backend logic

⸻

🎨 Major UI Refactor Needed
	•	Dashboard layout needs responsive scaling
	•	Modularize shared UI components (card spacing, typography)
	•	Consistent padding/margins throughout all feature views

⸻

🛠️ Contributing Guidelines

This project follows a strict architectural discipline to ensure maintainability, modularity, and onboarding efficiency.

Architectural Compliance
	•	MVVM Pattern:
	•	Views → ViewModels → Services → Data Layer
	•	SwiftUI Views:
	•	Must only bind to ObservableObject ViewModels
	•	Avoid logic in views beyond rendering and UI events
	•	ViewModels:
	•	Own all logic, Combine pipelines, and navigation state
	•	Testable in isolation (Preview & XCTest)
	•	Models:
	•	Plain Swift structs, Codable when needed
	•	Zero UI or logic dependencies
	•	Services:
	•	Singleton or injected
	•	Combine publishers and @Published properties only

⸻

Acceptance Criteria for Any New Feature
	1.	ViewModel First
The business logic must be encapsulated in a testable ViewModel.
	2.	Preview Compatibility
All Views must support SwiftUI Preview via test/mock data.
	3.	Single Responsibility
Break large views into visual components for each domain feature (Card, Section, Modal, etc.)
	4.	Adherence to Layer Boundaries
Views must not reference models or services directly.
ViewModels must call services and expose models to the view.
	5.	Scoring Consistency
Any new computation or score must:
	•	Be testable
	•	Follow the style of Readiness, Adherence, or Perceived Exertion
	6.	HealthKit Safety
All HK queries must:
	•	Respect background delivery constraints
	•	Avoid duplicate authorization prompts
	7.	AI Context Handling
When using the AI Assistant, strip all personal identifiers before sending to OpenAI.

⸻

📄 License

Athletica.OS is released under the MIT License. See LICENSE for details.

⸻

🙋 Contact

Built with ❤️ by the Athletica.OS team.

Train smart. Recover smarter.
