# Cursor Translator

A macOS menu bar app that allows you to select a screen area, extract text, and translate it.

## Features

- Lives in the macOS menu bar for easy access
- Select any area of the screen to capture text (similar to CMD+Shift+4)
- Automatically detects and extracts text from the selected area
- Translate text between multiple languages
- Simple and intuitive interface

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later

## Setup

1. Clone this repository
2. Open the `cursor-translator.xcodeproj` file in Xcode
3. Build and run the application

## Usage

1. Click the translator icon in the menu bar
2. Select your source and target languages
3. Click "Select Area to Translate"
4. Click and drag to select the area containing text you want to translate
5. The translated text will appear in the app's interface

## Implementation Notes

- The app uses Vision framework for OCR (Optical Character Recognition)
- The translation API is mocked for demonstration purposes. To make it functional, you'll need to integrate a real translation API such as Google Translate, DeepL, or Microsoft Translator
- The app demonstrates key macOS capabilities:
  - Menu bar app implementation
  - Screen selection and capture
  - OCR text recognition
  - SwiftUI interface

## Adding a Real Translation API

To implement actual translation, modify the `translateText` method in the `TranslatorViewModel.swift` file by:

1. Registering for a translation API service (Google Translate, DeepL, Microsoft Translator, etc.)
2. Obtaining an API key
3. Implementing the API call with proper authentication
4. Parsing the response to extract the translated text