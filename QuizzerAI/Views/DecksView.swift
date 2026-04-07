import SwiftUI
import SwiftData

/// The "Decks" tab — shows all Study Classes and lets the user create new ones.
/// Extracted from the original RootView so MainTabView can host it as a tab.
struct DecksView: View {
    @Query(sort: \StudyClass.createdAt, order: .reverse) private var classes: [StudyClass]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddClass = false
    @State private var newClassName = ""
    @State private var newClassSubject = ""
    @State private var createError: String?
    @State private var classToDelete: StudyClass?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color("BG").ignoresSafeArea()

                Group {
                    if classes.isEmpty {
                        emptyState
                    } else {
                        classList
                    }
                }

                addButton
            }
            .navigationTitle("QuizzerAI")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAddClass) {
            addClassSheet
        }
        .alert("Couldn't Save Class", isPresented: Binding(
            get: { createError != nil },
            set: { if !$0 { createError = nil } }
        )) {
            Button("OK", role: .cancel) { createError = nil }
        } message: {
            Text(createError ?? "")
        }
        .confirmationDialog(
            "Delete Class",
            isPresented: Binding(
                get: { classToDelete != nil },
                set: { if !$0 { classToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let c = classToDelete {
                    modelContext.delete(c)
                    do { try modelContext.save() } catch { createError = error.localizedDescription }
                    classToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { classToDelete = nil }
        } message: {
            if let c = classToDelete {
                Text("This will permanently delete \"\(c.name)\" and all its decks and flashcards.")
            }
        }
    }

    // MARK: - Class List

    private var classList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(classes) { studyClass in
                    NavigationLink {
                        ClassDetailView(studyClass: studyClass)
                    } label: {
                        ClassRowCard(studyClass: studyClass)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            classToDelete = studyClass
                        } label: {
                            Label("Delete Class", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color("AccentPurple").opacity(0.5))
            Text("No classes yet")
                .font(.title3.weight(.semibold))
            Text("Tap + to create your first class and start scanning.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            showAddClass = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("New Class")
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 28)
            .frame(height: 52)
            .background(Color("AccentPurple"), in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: Color("AccentPurple").opacity(0.4), radius: 12, y: 4)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Add Class Sheet

    private var addClassSheet: some View {
        NavigationStack {
            Form {
                Section("Class Details") {
                    TextField("Class name", text: $newClassName)
                    TextField("Subject (optional)", text: $newClassSubject)
                }
            }
            .navigationTitle("New Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddClass = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createClass() }
                        .disabled(newClassName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createClass() {
        let newClass = StudyClass(
            name: newClassName.trimmingCharacters(in: .whitespaces),
            subject: newClassSubject.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(newClass)
        do {
            try modelContext.save()
            newClassName = ""
            newClassSubject = ""
            showAddClass = false
        } catch {
            createError = error.localizedDescription
        }
    }
}

// MARK: - Class Row Card

struct ClassRowCard: View {
    let studyClass: StudyClass

    var body: some View {
        let total = studyClass.totalCount

        HStack(spacing: 16) {
            Circle()
                .fill(Color(hex: studyClass.colorHex))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(studyClass.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                if !studyClass.subject.isEmpty {
                    Text(studyClass.subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(total)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color("AccentPurple"))
                Text("cards")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 16))
    }
}
