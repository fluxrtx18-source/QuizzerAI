import Foundation

// MARK: - Step

enum OnboardingStep: Int, CaseIterable {
    case welcome          = 0
    case carousel         = 1
    case goalQ            = 2
    case levelQ           = 3
    case painPoints       = 4
    case socialProof      = 5
    case solution         = 6
    case cameraPermission = 7
    case appDemo          = 8
    case valueDelivery    = 9
    case paywall          = 10
}

// MARK: - Question

struct OnboardingQuestion {
    let speechBubble: String
    let options: [String]
}

enum OnboardingQuestions {
    static let goal = OnboardingQuestion(
        speechBubble: "What's your main goal with QuizzerAI?",
        options: [
            "📚 Memorize lecture notes faster",
            "🎯 Ace an upcoming exam",
            "📖 Review textbook chapters",
            "🧠 Build long-term memory",
            "💼 Professional certification",
            "✏️ Something else"
        ]
    )

    static let level = OnboardingQuestion(
        speechBubble: "Where are you in your learning journey?",
        options: [
            "🏫 High School",
            "🎓 College / University",
            "🔬 Grad School",
            "🌱 Self-Learning",
            "💼 Professional Training",
            "🗺️ Other"
        ]
    )
}

// MARK: - Pain Points

enum OnboardingPainPoints {
    static let speechBubble = "What gets in the way of studying?"
    static let options: [String] = [
        "⏱️ Making flashcards takes forever",
        "😴 Re-reading notes doesn't help me remember",
        "📱 I forget to study consistently",
        "💸 Other apps make me pay before I try",
        "☁️ I don't want my notes going to the cloud",
        "📝 Writing out cards is tedious",
        "📊 I can't tell if I'm actually making progress"
    ]
}

// MARK: - Social Proof

struct Testimonial: Identifiable {
    let id = UUID()
    let initials: String
    let name: String
    let persona: String
    let review: String
    let stars: Int
}

enum SocialProofData {
    static let headline = "Students are studying smarter"
    static let subheadline = "Create your first deck in under 2 minutes"

    static let testimonials: [Testimonial] = [
        Testimonial(
            initials: "PR",
            name: "Priya R.",
            persona: "Medical Student",
            review: "I scanned an entire anatomy chapter in 90 seconds. The cards were actually good — not just copied sentences. Insane.",
            stars: 5
        ),
        Testimonial(
            initials: "JM",
            name: "Jake M.",
            persona: "College Junior",
            review: "Went from dreading flashcards to making 50 of them on my lunch break. The on-device part matters to me too.",
            stars: 5
        ),
        Testimonial(
            initials: "ST",
            name: "Sofia T.",
            persona: "Bar Exam Prep",
            review: "Finally an app that does the annoying part for me. I just study. No more wasting an hour making the cards first.",
            stars: 5
        )
    ]
}

// MARK: - Personalised Solution

struct SolutionItem: Identifiable {
    let id = UUID()
    let icon: String           // SF Symbol
    let painPoint: String      // grey "before" label
    let solution: String       // bold "after" label
}

enum PersonalisedSolutionData {
    static let items: [SolutionItem] = [
        SolutionItem(
            icon: "bolt.fill",
            painPoint: "Hours making flashcards",
            solution: "Your full deck is ready in seconds — just scan the page"
        ),
        SolutionItem(
            icon: "brain.head.profile",
            painPoint: "Notes that don't stick",
            solution: "AI pulls out the testable facts, not filler text"
        ),
        SolutionItem(
            icon: "lock.shield.fill",
            painPoint: "Privacy worries",
            solution: "100% on-device — your notes never leave your phone"
        ),
        SolutionItem(
            icon: "gift.fill",
            painPoint: "Paying before you try",
            // Limit defined in StoreManager.freeCardLimit (currently 20).
            solution: "Your first \(StoreManager.freeCardLimit) flashcards are completely free"
        )
    ]

    static func headline(for goal: String) -> String {
        if goal.contains("exam") || goal.contains("Ace") {
            return "Here's how QuizzerAI gets you exam-ready"
        } else if goal.contains("Memorize") || goal.contains("memory") {
            return "Here's how QuizzerAI makes things stick"
        } else {
            return "Here's how QuizzerAI works for you"
        }
    }
}

// MARK: - Demo Flashcards

struct DemoFlashcard: Identifiable {
    let id = UUID()
    let subject: String
    let question: String
    let answer: String
    let accentHex: String
}

enum DemoFlashcards {
    static let cards: [DemoFlashcard] = [
        DemoFlashcard(
            subject: "Physics",
            question: "What is Newton's First Law of Motion?",
            answer: "An object at rest stays at rest, and an object in motion stays in motion — unless acted on by an external force.",
            accentHex: "#6E56FF"
        ),
        DemoFlashcard(
            subject: "Biology",
            question: "What is photosynthesis?",
            answer: "The process plants use to convert sunlight, CO₂, and water into glucose and oxygen.",
            accentHex: "#10B981"
        ),
        DemoFlashcard(
            subject: "Maths",
            question: "What is the quadratic formula?",
            answer: "x = (−b ± √(b² − 4ac)) / 2a\nSolves any equation of the form ax² + bx + c = 0.",
            accentHex: "#F59E0B"
        )
    ]
}

// MARK: - Feature card (carousel step)

struct FeatureCard: Identifiable {
    let id = UUID()
    let icon: String          // SF Symbol name
    let label: String
    let headline: String
    let body: String
    let accentHex: String
}

extension FeatureCard {
    static let all: [FeatureCard] = [
        FeatureCard(
            icon: "camera.viewfinder",
            label: "Scan Anything",
            headline: "Point. Shoot. Done.",
            body: "Capture any textbook page or handwritten note with your camera.",
            accentHex: "#6E56FF"
        ),
        FeatureCard(
            icon: "sparkles",
            label: "AI Extracts Cards",
            headline: "On-device AI, zero cloud.",
            body: "Apple Intelligence reads your scan and generates question & answer pairs — no internet needed.",
            accentHex: "#00C6FF"
        ),
        FeatureCard(
            icon: "bolt.fill",
            label: "Cram Anywhere",
            headline: "Flip. Track. Repeat.",
            body: "Study with tap-to-flip cards and track your score session by session.",
            accentHex: "#FF6B6B"
        )
    ]
}

// MARK: - UserDefaults keys

/// Typed namespace for UserDefaults keys — avoids polluting the global String namespace.
enum UserDefaultsKeys {
    static let onboardingComplete = "onboardingComplete"
    static let appearanceMode     = "appearanceMode"
    /// Number of free flashcards the user has consumed. Max = StoreManager.freeCardLimit.
    static let freeCardsUsed      = "freeCardsUsed"
}
