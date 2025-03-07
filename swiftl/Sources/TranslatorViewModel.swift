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
        self.sourceLanguage = availableLanguages[8] // Default to Japanese
        self.targetLanguage = availableLanguages[0] // Default to English
        
        // Load DeepL API key from Keychain if available
        if let apiKey = loadDeepLAPIKey() {
            self.deepLApiKey = apiKey
            self.isDeepLEnabled = !apiKey.isEmpty
        }
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
            print("Error saving API key to Keychain: \(status)")
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
        
        // Create a query dictionary to find and delete the key
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.swiftl.DeepLAPIKey",
            kSecAttrAccount as String: "DeepLAPIKey"
        ]
        
        SecItemDelete(keychainQuery as CFDictionary)
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
        print("Processing selected area: \(rect)")
        
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
                    print("Successfully recognized text: \(text)")
                    
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
            print("Failed to get CGImage from NSImage")
            completion(nil)
            return
        }
        
        // Get image dimensions for debugging
        let width = cgImage.width
        let height = cgImage.height
        print("Processing image for text recognition: \(width)x\(height)")
        
        // Don't process if the image is too small
        if width < 20 || height < 20 {
            print("Image too small for text recognition")
            completion(nil)
            return
        }
        
        // Get corresponding language code for Vision framework
        let languageHint = getVisionLanguageCode(for: sourceLanguage.code)
        print("Using language hint: \(languageHint)")
        
        // Create a text recognition request
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                print("Text recognition error in callback: \(String(describing: error))")
                completion(nil)
                return
            }
            
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            print("Found \(observations.count) text observations")
            
            if observations.isEmpty {
                print("No text observations found in the image")
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
                
                print("Text segment: '\(candidate.string)' at \(boundingBox) with confidence: \(candidate.confidence)")
            }
            
            print("Final recognized text: \(recognizedString)")
            
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
            print("Text recognition error during execution: \(error)")
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
    
    // Decode HTML entities in the translated text
    private func decodeHtmlEntities(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return string
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        
        // If HTML parsing fails, try manual replacement of common entities
        var result = string
        let entities = [
            "&quot;": "\"",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#x27;": "'",
            "&#x2F;": "/",
            "&#x60;": "`",
            "&#x3D;": "="
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Also handle numeric character references (&#nnnn;)
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let nsString = result as NSString
            let range = NSRange(location: 0, length: nsString.length)
            
            // Process matches in reverse order to avoid index shifting
            let matches = regex.matches(in: result, range: range).reversed()
            
            for match in matches {
                let codeRange = NSRange(location: match.range.location + 2, length: match.range.length - 3)
                let codeString = nsString.substring(with: codeRange)
                
                if let code = Int(codeString), let scalar = UnicodeScalar(code) {
                    let char = String(Character(scalar))
                    result = (result as NSString).replacingCharacters(in: match.range, with: char)
                }
            }
        }
        
        return result
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
            print("Failed to encode text for translation")
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
            print("Failed to create URL for DeepL API")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create API URL"
                completion(nil)
            }
            return
        }
        
        print("Making request to DeepL API")
        
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
                print("DeepL translation request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                print("DeepL response status code: \(httpResponse.statusCode)")
                
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
                print("DeepL API raw response: \(responseString)")
            }
            
            do {
                // Parse the DeepL API response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let translations = json["translations"] as? [[String: Any]],
                   let firstTranslation = translations.first,
                   let translatedText = firstTranslation["text"] as? String {
                    
                    print("DeepL translation result: \(translatedText)")
                    
                    DispatchQueue.main.async {
                        completion(translatedText)
                    }
                    return
                }
                
                // Failed to parse as expected
                print("Failed to parse DeepL translation response")
                DispatchQueue.main.async {
                    self.errorMessage = "Couldn't extract translation from DeepL response"
                    completion(nil)
                }
            } catch {
                print("Error parsing DeepL translation response: \(error.localizedDescription)")
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
            print("Failed to encode text for translation")
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
            print("Failed to create URL for Google Translate API")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create API URL"
                completion(nil)
            }
            return
        }
        
        print("Making request to: \(url.absoluteString)")
        
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
                print("Translation request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
                
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
                print("API raw response: \(responseString)")
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
                        print("Translation result: \(completeTranslation)")
                        
                        DispatchQueue.main.async {
                            completion(completeTranslation)
                        }
                        return
                    }
                }
                
                // Failed to parse as expected
                print("Failed to parse translation response")
                DispatchQueue.main.async {
                    self.errorMessage = "Couldn't extract translation from response"
                    completion(nil)
                }
            } catch {
                print("Error parsing translation response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Error processing translation result"
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
}
