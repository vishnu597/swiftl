import SwiftUI
import Vision
import AppKit
import Foundation
import Security

struct Language: Equatable, Hashable {
    let name: String
    let code: String
}

class TranslatorViewModel: ObservableObject {
    @Published var sourceLanguage: Language
    @Published var targetLanguage: Language
    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isSelectingArea: Bool = false
    @Published var deepLApiKey: String = ""
    @Published var isDeepLEnabled: Bool = false
    
    let availableLanguages: [Language] = [
        Language(name: "English", code: "en"),
        Language(name: "Spanish", code: "es"),
        Language(name: "French", code: "fr"),
        Language(name: "German", code: "de"),
        Language(name: "Italian", code: "it"),
        Language(name: "Portuguese (Brazil)", code: "pt-BR"),
        Language(name: "Portuguese (Portugal)", code: "pt-PT"),
        Language(name: "Russian", code: "ru"),
        Language(name: "Japanese", code: "ja"),
        Language(name: "Chinese (Simplified)", code: "zh-Hans"),
        Language(name: "Chinese (Traditional)", code: "zh-Hant"),
        Language(name: "Korean", code: "ko"),
        Language(name: "Arabic", code: "ar"),
        Language(name: "Dutch", code: "nl"),
        Language(name: "Hindi", code: "hi"),
        Language(name: "Indonesian", code: "id"),
        Language(name: "Thai", code: "th"),
        Language(name: "Turkish", code: "tr"),
        Language(name: "Ukrainian", code: "uk"),
        Language(name: "Vietnamese", code: "vi")
    ]
    
    // Window controller to manage the selection window's lifecycle
    private var windowController: NSWindowController?
    
    init() {
        // Default to Japanese and English, but will be overridden by saved preferences if they exist
        self.sourceLanguage = availableLanguages[8] // Default to Japanese
        self.targetLanguage = availableLanguages[0] // Default to English
        
        // Load DeepL API key from Keychain if available
        if let apiKey = loadDeepLAPIKey() {
            self.deepLApiKey = apiKey
            self.isDeepLEnabled = !apiKey.isEmpty
        }
        
        // Load saved language preferences
        loadLanguagePreferences()
    }
    
    // Save DeepL API key to Keychain
    func saveDeepLAPIKey(_ apiKey: String) {
        self.deepLApiKey = apiKey
        self.isDeepLEnabled = !apiKey.isEmpty
        
        // Create a query dictionary for the keychain
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.swiftl.DeepLAPIKey",
            kSecAttrAccount as String: "DeepLAPIKey",
            kSecValueData as String: apiKey.data(using: .utf8) ?? Data(),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing key before saving
        SecItemDelete(keychainQuery as CFDictionary)
        
        // Add the key to the keychain
        let status = SecItemAdd(keychainQuery as CFDictionary, nil)
        if status != errSecSuccess {
            // Error saving API key to Keychain
        }
    }
    
    // Load DeepL API key from Keychain
    private func loadDeepLAPIKey() -> String? {
        // Create a query dictionary to find the key
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.swiftl.DeepLAPIKey",
            kSecAttrAccount as String: "DeepLAPIKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &dataTypeRef)
        
        // Check if the operation was successful
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data,
               let apiKey = String(data: retrievedData, encoding: .utf8) {
                return apiKey
            }
        }
        
        return nil
    }
    
    // Remove DeepL API key from Keychain
    func removeDeepLAPIKey() {
        self.deepLApiKey = ""
        self.isDeepLEnabled = false
        
        // Create a query dictionary to find the key
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.swiftl.DeepLAPIKey",
            kSecAttrAccount as String: "DeepLAPIKey"
        ]
        
        // Delete the key from the keychain
        SecItemDelete(keychainQuery as CFDictionary)
    }
    
    // Save default language preferences to UserDefaults
    func saveLanguagePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(sourceLanguage.code, forKey: "DefaultSourceLanguageCode")
        defaults.set(targetLanguage.code, forKey: "DefaultTargetLanguageCode")
    }
    
    // Load default language preferences from UserDefaults
    private func loadLanguagePreferences() {
        let defaults = UserDefaults.standard
        
        if let sourceCode = defaults.string(forKey: "DefaultSourceLanguageCode"),
           let targetCode = defaults.string(forKey: "DefaultTargetLanguageCode") {
            
            // Find the languages that match the saved codes
            if let sourceLanguage = availableLanguages.first(where: { $0.code == sourceCode }),
               let targetLanguage = availableLanguages.first(where: { $0.code == targetCode }) {
                self.sourceLanguage = sourceLanguage
                self.targetLanguage = targetLanguage
            }
        }
    }
    
    func startAreaSelection() {
        // Make sure we're on the main thread
        DispatchQueue.main.async {
            self.isSelectingArea = true
            
            // If there's an existing window controller, close it
            if let windowController = self.windowController {
                windowController.close()
                self.windowController = nil
            }
            
            // Hide the app first
            NSApp.hide(nil)
            
            // Create the selection window
            let window = AreaSelectionWindow(viewModel: self)
            
            // Create a window controller to manage the window's lifecycle
            let controller = NSWindowController(window: window)
            self.windowController = controller
            
            // Show the window 
            controller.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            
            // Activate the app after a short delay to ensure proper window ordering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func processSelectedArea(rect: NSRect) {
        // Release the window controller reference
        DispatchQueue.main.async {
            self.windowController = nil
            self.isSelectingArea = false
        }
        
        DispatchQueue.main.async {
            self.isTranslating = true
            self.errorMessage = nil
            self.translatedText = ""
            
            // Show the app and its panel
            NSApp.unhide(nil)
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showPanel(NSStatusBarButton())
            }
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // Log the selected area for debugging
        
        // Ensure the rectangle is valid
        if rect.width <= 10 || rect.height <= 10 {
            DispatchQueue.main.async {
                self.isTranslating = false
                self.errorMessage = "Selected area is too small. Please select a larger area."
            }
            return
        }
        
        // Take a screenshot of the selected area
        if let image = captureScreenshot(of: rect) {
            // Extract text from the image
            recognizeText(in: image) { [weak self] recognizedText in
                guard let self = self else { return }
                
                if let text = recognizedText, !text.isEmpty {
                    
                    
                    // Translate the text
                    self.translateText(text) { translatedText in
                        DispatchQueue.main.async {
                            self.isTranslating = false
                            if let translatedText = translatedText {
                                self.translatedText = translatedText
                            } else {
                                self.errorMessage = "Translation failed. Please check your network connection or try a different language pair."
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isTranslating = false
                        self.errorMessage = "No text was recognized in the selected area."
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.isTranslating = false
                self.errorMessage = "Failed to capture screenshot."
            }
        }
    }
    
    private func captureScreenshot(of rect: NSRect) -> NSImage? {
        if let screenShot = CGWindowListCreateImage(
            rect, 
            .optionOnScreenOnly, 
            kCGNullWindowID, 
            [.boundsIgnoreFraming]
        ) {
            return NSImage(cgImage: screenShot, size: rect.size)
        }
        return nil
    }
    
    private func recognizeText(in image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            
            completion(nil)
            return
        }
        
        // Get image dimensions for debugging
        let width = cgImage.width
        let height = cgImage.height
        
        
        // Don't process if the image is too small
        if width < 20 || height < 20 {
            
            completion(nil)
            return
        }
        
        // Get corresponding language code for Vision framework
        let languageHint = getVisionLanguageCode(for: sourceLanguage.code)
        
        
        // Create a text recognition request
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                
                completion(nil)
                return
            }
            
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            
            
            if observations.isEmpty {
                
                completion(nil)
                return
            }
            
            // Create a simple string builder for the recognized text
            var recognizedString = ""
            var previousBottom: CGFloat = 1.0 // Vision coordinates are normalized [0,1]
            
            // Sort observations from top to bottom
            // Vision coordinates are normalized with the origin at the bottom-left
            let sortedObservations = observations.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            
            for observation in sortedObservations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                
                // Check if this is a new line (based on vertical position)
                let boundingBox = observation.boundingBox
                let top = boundingBox.maxY
                let lineThreshold = 0.01 // 1% of height
                
                if previousBottom - top > lineThreshold {
                    // This appears to be a new line
                    if !recognizedString.isEmpty {
                        recognizedString += "\n"
                    }
                } else if !recognizedString.isEmpty && !recognizedString.hasSuffix("\n") {
                    // Same line, add a space
                    recognizedString += " "
                }
                
                recognizedString += candidate.string
                previousBottom = boundingBox.minY
                
                
            }
            
            
            
            if recognizedString.isEmpty {
                completion(nil)
            } else {
                completion(recognizedString)
            }
        }
        
        // Configure the recognition request for optimal performance
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [languageHint]
        
        // DO NOT set a specific region of interest - this forces it to use the actual image bounds
        // request.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        // Use custom option to improve accuracy
        request.customWords = [] // No custom words needed
        request.minimumTextHeight = 0.01 // Allow smaller text to be recognized (1% of image height)
        request.revision = VNRecognizeTextRequestRevision2 // Use latest revision
        
        // Create a handler to process the image
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            
            completion(nil)
        }
    }
    
    // Convert ISO language code to Vision framework language code
    private func getVisionLanguageCode(for isoCode: String) -> String {
        // Map ISO language codes to Vision framework language codes
        let languageMap: [String: String] = [
            "en": "en-US",
            "fr": "fr-FR",
            "it": "it-IT",
            "de": "de-DE",
            "es": "es-ES",
            "pt": "pt-BR",
            "zh-Hans": "zh-Hans",
            "ja": "ja-JP",
            "ko": "ko-KR",
            "ru": "ru-RU",
            "ar": "ar-SA"
        ]
        
        return languageMap[isoCode] ?? "en-US"
    }
    
    private func translateText(_ text: String, completion: @escaping (String?) -> Void) {
        guard !text.isEmpty else {
            completion("")
            return
        }
        
        // Check if DeepL is enabled and we have an API key
        if isDeepLEnabled && !deepLApiKey.isEmpty {
            translateWithDeepL(text, completion: completion)
        } else {
            translateWithGoogleTranslate(text, completion: completion)
        }
    }
    
    private func translateWithDeepL(_ text: String, completion: @escaping (String?) -> Void) {
        // Create a proper URL-encoded string for the text
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            
            DispatchQueue.main.async {
                self.errorMessage = "Failed to encode text for translation"
                completion(nil)
            }
            return
        }
        
        // Convert language codes for DeepL if needed
        let from = convertToDeepLLanguageCode(sourceLanguage.code)
        let to = convertToDeepLLanguageCode(targetLanguage.code)
        
        // Build the URL for DeepL API
        let urlString = "https://api-free.deepl.com/v2/translate"
        
        guard let url = URL(string: urlString) else {
            
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create API URL"
                completion(nil)
            }
            return
        }
        
        
        
        // Create the request body
        var requestBody = "text=\(encodedText)"
        requestBody += "&source_lang=\(from)"
        requestBody += "&target_lang=\(to)"
        
        // Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestBody.data(using: .utf8)
        
        // Set headers for DeepL API
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("DeepL-Auth-Key \(deepLApiKey)", forHTTPHeaderField: "Authorization")
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                
                
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        self.errorMessage = "DeepL API Error: HTTP \(httpResponse.statusCode)"
                        completion(nil)
                    }
                    return
                }
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received from DeepL API"
                    completion(nil)
                }
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                
            }
            
            do {
                // Parse the DeepL API response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let translations = json["translations"] as? [[String: Any]],
                   let firstTranslation = translations.first,
                   let translatedText = firstTranslation["text"] as? String {
                    
                    
                    
                    DispatchQueue.main.async {
                        completion(translatedText)
                    }
                    return
                }
                
                // Failed to parse as expected
                
                DispatchQueue.main.async {
                    self.errorMessage = "Couldn't extract translation from DeepL response"
                    completion(nil)
                }
            } catch {
                
                DispatchQueue.main.async {
                    self.errorMessage = "Error processing DeepL translation result"
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
    
    private func convertToDeepLLanguageCode(_ code: String) -> String {
        // Map language codes to DeepL supported codes
        // DeepL has different format requirements for some languages
        let languageMap: [String: String] = [
            "en": "EN",
            "es": "ES",
            "fr": "FR",
            "de": "DE",
            "it": "IT",
            "ja": "JA",
            "ko": "KO",
            "pt-BR": "PT-BR",
            "pt-PT": "PT-PT",
            "ru": "RU",
            "zh-Hans": "ZH", // Simplified Chinese
            "zh-Hant": "ZH", // Traditional Chinese
            "nl": "NL",
            "pl": "PL",
            "tr": "TR",
            "uk": "UK",
            "ar": "AR",
            "hi": "HI"
        ]
        
        return languageMap[code] ?? "EN"
    }
    
    private func translateWithGoogleTranslate(_ text: String, completion: @escaping (String?) -> Void) {
        // Create a proper URL-encoded string for the text
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            
            DispatchQueue.main.async {
                self.errorMessage = "Failed to encode text for translation"
                completion(nil)
            }
            return
        }
        
        // Use source and target language codes
        let from = sourceLanguage.code
        let to = targetLanguage.code
        
        // Generate a semi-random token for the request (mimicking browser behavior)
        let randomToken = Int.random(in: 100000...10000000)
        
        // Build the URL with the format used by free Google Translate
        let urlString = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(from)&tl=\(to)&dt=t&q=\(encodedText)&tk=\(randomToken)"
        
        guard let url = URL(string: urlString) else {
            
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create API URL"
                completion(nil)
            }
            return
        }
        
        
        
        // Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set headers to mimic a browser request
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                
                
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        self.errorMessage = "API Error: HTTP \(httpResponse.statusCode)"
                        completion(nil)
                    }
                    return
                }
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received from translation API"
                    completion(nil)
                }
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                
            }
            
            do {
                // Parse the Google Translate free API response format
                // The format is an array of arrays, with the first sub-array containing translation segments
                if let json = try JSONSerialization.jsonObject(with: data) as? [Any],
                   let translations = json[0] as? [[Any]] {
                    
                    // Concatenate all translation segments to get the full translated text
                    var completeTranslation = ""
                    
                    for translationPart in translations {
                        if let translatedText = translationPart[0] as? String {
                            completeTranslation += translatedText
                        }
                    }
                    
                    if !completeTranslation.isEmpty {
                        
                        
                        DispatchQueue.main.async {
                            completion(completeTranslation)
                        }
                        return
                    }
                }
                
                // Failed to parse as expected
                
                DispatchQueue.main.async {
                    self.errorMessage = "Couldn't extract translation from response"
                    completion(nil)
                }
            } catch {
                
                DispatchQueue.main.async {
                    self.errorMessage = "Error processing translation result"
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
}
