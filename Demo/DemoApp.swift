import HybridInference
import HybridInferenceUI
import SwiftUI

/// The demo owns its scenario: the dataset, the teacher's rules, the price and the budget are product
/// decisions, so they live in the app and are handed to the library's view.
@main
struct HybridInferenceDemoApp: App {
    private let scenario: LabScenario?
    private let stage: LabStage

    init() {
        scenario = SupportTriageScenario.make()
        stage = LaunchOptions.stage(from: ProcessInfo.processInfo.arguments)
    }

    var body: some Scene {
        WindowGroup {
            if let scenario {
                HybridInferenceLabView(scenario: scenario, initialStage: stage)
            } else {
                ContentUnavailableView(
                    "Scenario data is invalid",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The compiled-in eval set could not be built.")
                )
            }
        }
    }
}

/// `-stage fresh|baseline|retrained|drifted|outage` opens the lab in that state (used for screenshots).
enum LaunchOptions {
    static func stage(from arguments: [String]) -> LabStage {
        guard let flag = arguments.firstIndex(of: "-stage") else { return .baseline }
        let valueIndex = arguments.index(after: flag)
        guard arguments.indices.contains(valueIndex) else { return .baseline }
        return LabStage(rawValue: arguments[valueIndex]) ?? .baseline
    }
}

/// A four-label support-ticket triage feature: billing, bug, account, feature.
enum SupportTriageScenario {
    static func make() -> LabScenario? {
        guard let evalSet = try? EvalSet(version: "tickets-eval-1", examples: eval) else { return nil }
        return LabScenario(
            title: "Ticket triage",
            seed: seed,
            evalSet: evalSet,
            trafficBatches: [dayOne, dayTwo],
            teacherModelID: "scripted-claude",
            teacherRules: rules,
            teacherFallback: "feature",
            configuration: RouterConfiguration(
                policy: EscalationPolicy(minConfidence: 1, minMargin: 0, minKnownTokenFraction: 0.25),
                budget: BudgetConfiguration(capacityUnits: 60, windowSeconds: 3600),
                pricePerCallUnits: 1,
                breaker: BreakerConfiguration(failureThreshold: 3, cooldownSeconds: 30),
                teacherTimeout: .seconds(4),
                shadowSampleRate: 0.2,
                shadowSalt: "triage-shadow-3",
                shadowQueueCapacity: 32,
                shadowHeadroomUnits: 10,
                harvestCapacity: 500
            ),
            targetPrecision: 0.9,
            gate: PromotionGate(maxAccuracyDrop: 0, maxRecallDrop: 0.05, minLocalPrecision: 0.9),
            shadowCallsPerRun: 8
        )
    }

    /// The scripted teacher's rules, checked in order. They stand in for Claude so the demo runs offline.
    static let rules: [ScriptedTeacher.Rule] = [
        .init(keywords: ["crash", "crashes", "freezes", "error", "broken", "bug", "blank", "stuck", "fails"], label: "bug"),
        .init(keywords: ["refund", "charged", "invoice", "payment", "subscription", "price", "receipt", "billing", "card"], label: "billing"),
        .init(keywords: ["password", "login", "email", "locked", "username", "account", "accounts", "sign"], label: "account"),
        .init(keywords: ["add", "wish", "would", "request", "feature", "export"], label: "feature"),
    ]

    /// Eight hand-labelled examples: all student v1 knows.
    static let seed: [LabeledExample] = [
        .init(text: "I was charged twice for my subscription", label: "billing"),
        .init(text: "Please send the invoice for last month", label: "billing"),
        .init(text: "The app crashes when I open settings", label: "bug"),
        .init(text: "Screen freezes after I log in", label: "bug"),
        .init(text: "I forgot my password", label: "account"),
        .init(text: "Cannot change the email on my account", label: "account"),
        .init(text: "Please add dark mode", label: "feature"),
        .init(text: "I wish I could export to PDF", label: "feature"),
    ]

    /// Held out. Never trained on: `TrainingSetBuilder` drops anything that matches it.
    static let eval: [LabeledExample] = [
        .init(text: "Why was my card charged again", label: "billing"),
        .init(text: "Refund the annual plan please", label: "billing"),
        .init(text: "Receipt shows the wrong price", label: "billing"),
        .init(text: "Photos fail with an error on upload", label: "bug"),
        .init(text: "The widget is blank on my home screen", label: "bug"),
        .init(text: "Sync is stuck at fifty percent", label: "bug"),
        .init(text: "Reset link for my password never arrives", label: "account"),
        .init(text: "My account is locked after three tries", label: "account"),
        .init(text: "How do I change my username", label: "account"),
        .init(text: "Would love a landscape mode on iPad", label: "feature"),
        .init(text: "Please add a shortcut for quick notes", label: "feature"),
        .init(text: "Wish the calendar had a week view", label: "feature"),
    ]

    static let dayOne: [String] = [
        "I was charged for a plan I cancelled",
        "Need a refund for the duplicate payment",
        "Where can I download my invoice",
        "The price went up without notice",
        "My card was charged but nothing unlocked",
        "Send me a receipt for the annual subscription",
        "Refund please, I bought it by mistake",
        "Payment failed but the money left my bank",
        "Billing shows two charges this month",
        "Can I get a refund on the family plan",
        "The app crashes on launch since the update",
        "Upload fails with an unknown error",
        "Home screen widget stays blank",
        "Video playback freezes after ten seconds",
        "Search is broken for names with accents",
        "Sync gets stuck and never finishes",
        "Crash when I rotate the phone",
        "Error message when saving a photo",
        "Notifications are broken after the update",
        "Settings screen is blank on iPad",
        "I cannot reset my password",
        "My account got locked after the update",
        "Change the email address on my account",
        "Login code never arrives by email",
        "Can I pick a new username",
        "Two factor login keeps failing",
        "Password reset link expired",
        "Someone else signed into my account",
        "Locked out after too many login attempts",
        "Merge my two accounts into one",
        "Please add a dark mode",
        "Would love an Apple Watch app",
        "Wish there was a landscape layout",
        "Feature request: export to CSV",
        "Please add widgets for the lock screen",
        "Would be great to share lists with family",
        "Request: keyboard shortcuts on iPad",
        "I wish the timer had custom sounds",
        "Add an option to hide completed tasks",
        "Would love Siri support for quick add",
    ]

    /// New tickets: neither student trained on these, so day two measures the retrain out of sample.
    static let dayTwo: [String] = [
        "Charged after my free trial ended",
        "Refund for an accidental purchase",
        "Invoice is missing my company name",
        "Why is the price higher in my country",
        "My card was charged three times",
        "App crashes when I tap share",
        "Export fails with an error code",
        "Calendar view is blank after sync",
        "Keyboard freezes in the notes editor",
        "Dark mode is broken on the settings page",
        "I cannot log into my account",
        "Password change keeps failing",
        "Email verification never arrives",
        "My username is already taken",
        "Account locked after password reset",
        "Would love a widget for the home screen",
        "Please add folders for notes",
        "Wish I could sync with Google Calendar",
        "Feature request: pin favourite lists",
        "Add support for Apple Pencil",
    ]
}
