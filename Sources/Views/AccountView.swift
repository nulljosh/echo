import SwiftUI

/// The Account row in Settings: sign in when signed out, the profile when signed in.
struct AccountSection: View {
    @ObservedObject var account: Account

    var body: some View {
        Section {
            if let user = account.user {
                NavigationLink { ProfileView(account: account) } label: {
                    LabeledContent(user.name.isEmpty ? "Account" : user.name, value: user.email)
                }
            } else {
                NavigationLink("Sign In or Create Account") { SignInView(account: account) }
                    .accessibilityIdentifier("account-sign-in")
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Optional. Echo works fully without one, and your transcripts never leave this device.")
        }
    }
}

struct SignInView: View {
    @ObservedObject var account: Account
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?

    private var emailOK: Bool { email.contains("@") && email.contains(".") }
    private var ready: Bool { emailOK && password.count >= 8 && (!creating || !name.trimmingCharacters(in: .whitespaces).isEmpty) }

    var body: some View {
        Form {
            Picker("Mode", selection: $creating) {
                Text("Sign In").tag(false)
                Text("Create Account").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                if creating {
                    TextField("Name", text: $name)
                        #if os(iOS)
                        .textContentType(.name)
                        #endif
                }
                TextField("Email", text: $email)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField("Password", text: $password)
                    #if os(iOS)
                    .textContentType(creating ? .newPassword : .password)
                    #endif
            } footer: {
                if creating { Text("At least 8 characters. We'll email you a link to confirm.") }
            }

            Section {
                Button(creating ? "Create Account" : "Sign In") { submit() }
                    .disabled(!ready || account.busy)
                if !creating {
                    Button("Forgot Password?") { reset() }
                        .disabled(!emailOK || account.busy)
                }
            }

            if let message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Account")
        .onChange(of: creating) { _, _ in message = nil }
    }

    private func submit() {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        Task {
            do {
                if creating {
                    try await account.signUp(name: name.trimmingCharacters(in: .whitespaces), email: email, password: password)
                    creating = false
                    password = ""
                    message = "Check \(email) for a link to confirm, then sign in here."
                } else {
                    try await account.signIn(email: email, password: password)
                    dismiss()
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func reset() {
        Task {
            do {
                try await account.sendReset(email: email.trimmingCharacters(in: .whitespaces).lowercased())
                message = "If that email has an account, a reset link is on its way."
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

struct ProfileView: View {
    @ObservedObject var account: Account
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmDelete = false
    @State private var message: String?

    private var changed: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed != account.user?.name
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $name).onSubmit(save)
                if changed { Button("Save", action: save).disabled(account.busy) }
            }
            Section {
                LabeledContent("Email", value: account.user?.email ?? "")
            }
            Section {
                Button("Sign Out") {
                    Task { await account.signOut(); dismiss() }
                }
            }
            Section {
                Button("Delete Account", role: .destructive) { confirmDelete = true }
                    .disabled(account.busy)
            } footer: {
                Text("Removes your account, name and email from our server. Transcripts stay on this device.")
            }
            if let message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Account")
        .onAppear { name = account.user?.name ?? "" }
        .confirmationDialog("Delete your Echo account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do { try await account.deleteAccount(); dismiss() }
                    catch { message = error.localizedDescription }
                }
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func save() {
        guard changed else { return }
        Task {
            do { try await account.rename(name.trimmingCharacters(in: .whitespaces)); message = nil }
            catch { message = error.localizedDescription }
        }
    }
}
