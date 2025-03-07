import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TranslatorViewModel
    @State private var apiKeyInput: String = ""
    @State private var isEditing: Bool = false
    
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
            
            Text("Language Settings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("Default languages can be changed from the main screen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
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
        .frame(width: 450, height: 450)
        .onAppear {
            apiKeyInput = viewModel.deepLApiKey
        }
    }
}

#Preview {
    SettingsView(viewModel: TranslatorViewModel())
}