import SwiftUI
import Foundation
import AppKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: TranslatorViewModel
    @State private var showingSettings = false
    @State private var showCopyFeedback = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Translation Settings")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
            .padding(.top, 12)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Language:")
                Picker("Source", selection: $viewModel.sourceLanguage) {
                    ForEach(viewModel.availableLanguages, id: \.code) { language in
                        Text(language.name).tag(language)
                    }
                }
                .labelsHidden()
                
                Text("Target Language:")
                Picker("Target", selection: $viewModel.targetLanguage) {
                    ForEach(viewModel.availableLanguages, id: \.code) { language in
                        Text(language.name).tag(language)
                    }
                }
                .labelsHidden()
            }
            .padding(.bottom, 8)
            
            Button("Select Area to Translate") {
                viewModel.startAreaSelection()
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(viewModel.isTranslating)
            
            if viewModel.isTranslating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 5)
                    Text("Translating...")
                }
                .padding(.top, 10)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            
            if !viewModel.translatedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Translation Result:")
                        .font(.headline)
                    
                    ScrollView {
                        Text(viewModel.translatedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 200)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // Copy button
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.translatedText, forType: .string)
                        
                        // Show feedback
                        showCopyFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopyFeedback = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text(showCopyFeedback ? "Copied!" : "Copy")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderless)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Spacer()
        }
        .padding([.horizontal, .bottom])
        .frame(width: 300, height: 400)
        .sheet(isPresented: $showingSettings) {
            // Pass the view model to the settings view
            SettingsView(viewModel: viewModel)
        }
    }
}