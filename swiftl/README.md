# Cursor Translator

A macOS menu bar app that allows you to select a screen area, extract text, and translate it.

## Features

- Lives in the macOS menu bar for easy access
- Select any area of the screen to capture text (similar to CMD+Shift+4)
- Automatically detects and extracts text from the selected area
- Translate text between multiple languages
- Simple, lightweight, and intuitive interface

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later

## Setup

1. Grab the latest Github Release or clone this repository
2. Open the `cursor-translator.xcodeproj` file in Xcode
3. Build and run the application

## Usage

1. Open DMG File and drag drop SwifTL into Applications folder
2. Navigate to Settings > Privacy & Security to Allow SwifTL to run
3. Click the translator icon in the menu bar
4. Select your source and target languages
5. Click "Select Area to Translate"
6. Click and drag to select the area containing text you want to translate
7. The translated text will appear in the app's interface

## Implementation Notes

- The app uses Vision framework for OCR (Optical Character Recognition)
- SwifTL uses a free Google Translate Web API to be offered 100% FREE. If you would like to use your own DeepL API key you can do so from the SwifTL settings.
