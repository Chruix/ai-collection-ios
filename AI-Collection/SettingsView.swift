import SwiftUI

struct SettingsView: View {
    @Binding var apiBaseURL: String
    @Binding var isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var urlInput: String = ""
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            Form {
                descriptionSection
                apiSection
                appearanceSection
                saveSection
                resetSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                ToastOverlay(visible: showSavedToast, text: "Saved")
            }
            .animation(.easeInOut(duration: 0.25), value: showSavedToast)
            .onAppear {
                urlInput = apiBaseURL
            }
        }
    }

    // MARK: - Sections

    private var descriptionSection: some View {
        Section {
            Text("Connect to a running Python backend service.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var apiSection: some View {
        Section("API Server Address") {
            TextField("http://localhost:8777", text: $urlInput)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(.body, design: .monospaced))
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle("Dark Mode", isOn: $isDarkMode)
        }
    }

    private var saveSection: some View {
        Section {
            Button(action: saveAndApply) {
                HStack {
                    Spacer()
                    Text("Save & Apply")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive, action: resetToDefault) {
                HStack {
                    Spacer()
                    Text("Reset to Default")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func saveAndApply() {
        let trimmed = urlInput
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        apiBaseURL = trimmed
        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    private func resetToDefault() {
        apiBaseURL = "http://localhost:8777"
        urlInput = apiBaseURL
    }
}

// MARK: - Toast Overlay

private struct ToastOverlay: View {
    let visible: Bool
    let text: String

    var body: some View {
        if visible {
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
        }
    }
}
