Goal Widget App

A widget-first goal tracking application featuring a reactive cat mascot, inspired by Duolingo's emotion-driven coaching model.

The app prioritizes immediate action from the home screen: users can log goals, snooze reminders, and stay consistent without opening the main app, while the mascot provides contextual emotional feedback.

Built with a modern 2026 architecture:
	•	Flutter for the core application
	•	Native interactive widgets on iOS and Android
	•	Deterministic urgency and mood engine
	•	State-based mascot rendering (OS-compliant)

⸻

Core Principles
	•	Widget-first UX – the widget is the primary interaction surface
	•	Single-tap actions – log progress directly from the widget
	•	Emotion-driven feedback – mood and mascot behavior guide user action
	•	OS-compliant rendering – no continuous animations or background work
	•	Battery-efficient design – snapshot-based updates
	•	Cross-platform without sacrificing native quality

⸻

The Cat Mascot

The application includes a reactive cat mascot embedded directly in the widget. The mascot acts as a lightweight behavioral coach, responding to user progress and urgency.

Design Constraint

Home screen widgets cannot run unrestricted animations. Animation is therefore achieved through:
	•	Pre-rendered static image frames
	•	Discrete emotional state changes
	•	Controlled widget refresh events

This approach is consistent with best-in-class widget implementations.

⸻

Mascot State Model

The mascot is implemented as a finite state machine, not a real-time animation system.

Mascot State Fields
	•	emotion: happy | neutral | worried | sad | celebrate
	•	frameIndex: integer index into a frame set
	•	expiresAt: optional timestamp for temporary states

Each widget render displays a single static frame.

⸻

Mascot Emotions

Emotion	Interpretation
happy	Goal completed or user ahead of schedule
neutral	User on track
worried	User behind schedule
sad	Goal missed or high risk
celebrate	Immediate reward after logging progress

The mascot's pose and expression reflect the current emotional state.

⸻

Mascot Rendering Strategy

Motion is simulated via frame swapping:

cat_happy_0 → cat_happy_1
cat_worried_0 → cat_worried_1
cat_celebrate_0 → cat_celebrate_1

Frame progression occurs only when:
	•	A user triggers a widget action
	•	A scheduled widget refresh is executed

No timers, animation loops, or background execution are used.

⸻

Application Behavior

Users can create goals such as:
	•	Drinking water (daily target)
	•	Exercise (daily completion)
	•	Long-term goals with milestones
	•	Custom scheduled or quota-based goals

The widget:
	•	Displays the most urgent goal at the current time
	•	Shows progress, deadline, and mascot state
	•	Allows instant logging or snoozing

⸻

Architecture Overview

Flutter App (source of truth)
   ├── Goal models and schedules
   ├── Progress and history
   ├── Urgency and mood engine
   ├── Mascot state rules
   └── Widget snapshot writer

Native Widgets
   ├── Read snapshot
   ├── Render UI and mascot frame
   └── Execute instant actions

Widgets are strictly render-only and contain no business logic.

⸻

Technology Stack

Core Application
	•	Flutter (Material 3 and Cupertino)
	•	Clean architecture (domain, logic, data layers)

iOS
	•	SwiftUI and WidgetKit
	•	AppIntents for interactive widget actions
	•	App Group–based shared storage

Android
	•	Kotlin and Jetpack Glance
	•	ActionCallback-based widget interactions
	•	DataStore or SharedPreferences

⸻

Widget Snapshot System

Widgets render from a small, cached JSON snapshot written by the app.

{
  "version": 2,
  "generatedAt": 1768327260,
  "topGoal": {
    "id": "water",
    "title": "Drink water",
    "progress": 0.625,
    "goalType": "daily",
    "progressType": "numeric",
    "nextDueEpoch": 1768336200,
    "urgency": 0.82,
    "progressLabel": "5/8 glasses"
  },
  "mascot": {
    "emotion": "worried",
    "frameIndex": 0
  }
}

This snapshot fully defines the widget UI and mascot behavior.

⸻

Urgency and Mood Engine

Each goal is assigned an urgency score (0–1) derived from:
	•	Progress versus target
	•	Time remaining until the next deadline
	•	Missed actions or streak risk

Urgency is mapped to mood states:
	•	happy – ahead of schedule
	•	neutral – on track
	•	worried – behind schedule
	•	sad – missed or critical

The mascot emotion is derived directly from this mapping.

⸻

Celebration State

When a user logs progress:
	•	The mascot enters the celebrate state
	•	The frame index resets
	•	The state persists for a short, fixed duration

After expiration, the mascot reverts to the computed mood state.

This provides immediate positive reinforcement without excessive stimulation.

⸻

Widget Interaction Model

Supported Actions
	•	Log progress (increment or complete)
	•	Snooze reminder (temporary deferment)
	•	Open application (detailed view)

Refresh Strategy
	•	Immediate refresh after user actions
	•	Scheduled refreshes (morning, midday, evening)
	•	Daily rollover at midnight

⸻

Project Structure

lib/
 ├── domain/          # Goal models
 ├── logic/           # Urgency and mascot engine
 ├── data/            # Repositories
 └── widget_snapshot.dart

ios/
 └── GoalWidget/
     ├── GoalWidget.swift
     └── LogGoalIntent.swift

android/
 └── goalwidget/
     ├── GoalWidget.kt
     └── LogGoalAction.kt


⸻

Development Workflow
	1.	Implement business logic in Flutter
	2.	Generate widget snapshot
	3.	Mirror urgency and mascot rules in Swift and Kotlin
	4.	Build native widgets
	5.	Iterate using Cursor-assisted refactoring

⸻

Privacy
	•	No advertising
	•	No data monetization
	•	Goal data remains on-device unless synchronization is explicitly enabled

⸻

Roadmap
	•	Expanded mascot pose library
	•	Goal-specific mascot behavior
	•	HealthKit and Health Connect integration
	•	Adaptive urgency modeling
	•	Cross-device synchronization

⸻

Design Philosophy

Minimal friction.
Correct timing.
Measured emotional feedback.

The widget is designed to act as a calm behavioral guide, not a source of noise.
