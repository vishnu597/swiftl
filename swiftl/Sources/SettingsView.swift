import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TranslatorViewModel
    @State private var apiKeyInput: String = ""
    @State private var isEditing: Bool = false
    @State private var selectedSourceLanguage: Language
    @State private var selectedTargetLanguage: Language
    @State private var showLanguageSavedAlert: Bool = false
    
    init(viewModel: TranslatorViewModel) {
        self.viewModel = viewModel
        // Initialize the state properties with the current values from the view model
        _selectedSourceLanguage = State(initialValue: viewModel.sourceLanguage)
        _selectedTargetLanguage = State(initialValue: viewModel.targetLanguage)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SwifTL Settings")
                .font(.headline)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Translation Service")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("Current service:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.isDeepLEnabled ? "DeepL API" : "Google Translate (free)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.isDeepLEnabled ? .green : .blue)
                }
                
                Text("SwifTL uses Google Translate's free web API by default")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("You can also use DeepL for translation by providing your own API key below")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("DeepL API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !viewModel.isDeepLEnabled || isEditing {
                    HStack {
                        SecureField("Enter your DeepL API key", text: $apiKeyInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(!isEditing && viewModel.isDeepLEnabled)

                        Button(viewModel.isDeepLEnabled ? "Save" : "Add") {
                            viewModel.saveDeepLAPIKey(apiKeyInput)
                            isEditing = false
                        }
                        .disabled(apiKeyInput.isEmpty)
                    }
                    .padding(.bottom, 4)
                } else {
                    HStack {
                        Text("API key saved")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Spacer()
                        
                        Button("Edit") {
                            apiKeyInput = viewModel.deepLApiKey
                            isEditing = true
                        }
                        
                        Button("Remove") {
                            viewModel.removeDeepLAPIKey()
                            apiKeyInput = ""
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Text("Your API key is securely stored in macOS Keychain")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Text("Default Language Settings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Default source language:")
                        .font(.caption)
                    
                    Picker("", selection: $selectedSourceLanguage) {
                        ForEach(viewModel.availableLanguages, id: \.code) { language in
                            Text(language.name).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                
                HStack(spacing: 8) {
                    Text("Default target language:")
                        .font(.caption)
                    
                    Picker("", selection: $selectedTargetLanguage) {
                        ForEach(viewModel.availableLanguages, id: \.code) { language in
                            Text(language.name).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                
                HStack {
                    Button("Save Defaults") {
                        viewModel.sourceLanguage = selectedSourceLanguage
                        viewModel.targetLanguage = selectedTargetLanguage
                        viewModel.saveLanguagePreferences()
                        showLanguageSavedAlert = true
                    }
                    .disabled(selectedSourceLanguage == selectedTargetLanguage)
                    
                    if showLanguageSavedAlert {
                        Text("Default languages saved!")
                            .foregroundColor(.green)
                            .font(.caption)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showLanguageSavedAlert = false
                                }
                            }
                    }
                }
                
                if selectedSourceLanguage == selectedTargetLanguage {
                    Text("Source and target languages must be different")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Text("These languages will be loaded by default when you start the app")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            HStack {
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .padding()
        .frame(width: 450, height: 520)
        .onAppear {
            apiKeyInput = viewModel.deepLApiKey
            selectedSourceLanguage = viewModel.sourceLanguage
            selectedTargetLanguage = viewModel.targetLanguage
        }
    }
}

#Preview {
    SettingsView(viewModel: TranslatorViewModel())
}