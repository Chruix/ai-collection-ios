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
                Section {
                    Text("AI Collection 需要连接到运行中的 Python 后端服务。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("API 服务器地址") {
                    TextField("http://localhost:8777", text: $urlInput)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .onAppear {
                            urlInput = apiBaseURL
                        }
                }

                Section("外观") {
                    Toggle("深色模式", isOn: $isDarkMode)
                }

                Section {
                    Button(action: {
                        let trimmed = urlInput
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        apiBaseURL = trimmed
                        showSavedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("保存并应用")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section {
                    Button(role: .destructive) {
                        apiBaseURL = "http://localhost:8777"
                        urlInput = apiBaseURL
                    } label: {
                        HStack {
                            Spacer()
                            Text("重置为默认地址")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    Text("已保存")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showSavedToast)
        }
    }
}
