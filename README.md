# Folio

A Flutter document editor for Android — open, edit, and save `.odt` files with the quality and fluency of modern document editors.

## About

Folio aims to be a first-class document editing experience on Android. The goal is parity with Google Docs and Microsoft Word in terms of text formatting fidelity, while keeping the app fast, lightweight, and focused on the `.odt` format.

## Features

- **ODF Parsing** — Reads `.odt` files with support for headings, bold/italic/underline formatting, lists, hyperlinks, colors, font sizes, images, and tables
- **Rich Text Editing** — Full editing with a formatting toolbar (flutter_quill)
- **Save & Load** — Overwrite the original file or save a new copy to local storage
- **File Picker** — Open documents from local storage via Android SAF (no extra permissions needed on Android 10+)
- **Import / Export** — Open and export plain text (`.txt`) and Markdown (`.md`)
- **Recent Files** — Quickly reopen recently edited documents from the home screen
- **Auto-save Drafts** — Debounced background drafts protect work against unexpected exits

## Roadmap

- [x] ODF parser + viewer
- [x] File picker (Android SAF)
- [x] CI/CD (GitHub Actions — lint + test on every PR)
- [x] Rich text editing (bold, italic, underline, lists, headings)
- [x] Save to `.odt` (OdfSerializer: Delta → ODF XML → ZIP)
- [x] Images (base64), tables (text), advanced styles (color, font-size)
- [x] UI/UX redesign — visual identity ("Studio") and usability
- [ ] Formatting fidelity — reach Google Docs / Word quality
- [ ] Native table editing
- [ ] Advanced media (images, embedded objects)
- [ ] Footnotes, comments, and document metadata
- [ ] Play Store release

## Tech Stack

- **Flutter** (Dart, Android focus)
- **flutter_quill** — rich text editor with Delta format
- **archive** — ZIP parsing for ODF containers
- **xml** — ODF content XML parsing
- **file_picker** — Android SAF document access
- **path_provider** — local storage for save operations

## Getting Started

```bash
flutter pub get
flutter run
```

## License

[MIT](LICENSE)
