# DropShelf

A macOS utility for temporarily storing files and folders while working with Finder.

## Screenshots & Icon

<p align="center">
  <img src="docs/app-icon.png" alt="DropShelf Icon" width="128"/>
</p>

<p align="center">
  <img src="docs/screenshot-main.png" alt="Main Window" width="600"/>
</p>

<p align="center">
  <img src="docs/screenshot-statusbar.png" alt="Status Bar" width="400"/>
</p>

## Description

DropShelf is a lightweight macOS application that creates a floating panel for temporary file storage. The app lives in the status bar and allows you to quickly save files you're dragging to use them later.

## Features

- Floating panel for storing files
- Automatic appearance when shaking the mouse while dragging a file
- Quick access via status bar icon
- File visualization with icons and names
- Drag and drop files to and from the panel
- Remove files from the panel with one click

## Technologies

- Swift
- SwiftUI
- AppKit (NSStatusItem, NSPanel)
- Drag & Drop API

## Requirements

- macOS 13.0+
- Xcode 14.0+

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd DropShelf
```

2. Open the project in Xcode:
```bash
open DropShelf.xcodeproj
```

3. Build and run the project (⌘R)

## Usage

1. After launch, the app will appear in the status bar
2. Click the status bar icon to open/close the panel
3. Drag files onto the panel to save them
4. Or start dragging a file and shake the mouse - the panel will appear automatically
5. Drag files from the panel to wherever you need them
6. Click the close button on a file to remove it from the panel

## Project Structure

- [DropShelfApp.swift](DropShelf/DropShelfApp.swift) - application entry point
- [AppDelegate.swift](DropShelf/AppDelegate.swift) - main application logic, status bar management
- [FloatingPanelWindow.swift](DropShelf/FloatingPanelWindow.swift) - floating panel window
- [ShelfViewController.swift](DropShelf/ShelfViewController.swift) - file panel controller
- [OverlapStackView.swift](DropShelf/OverlapStackView.swift) - custom overlapping stack view
- [FileItemView.swift](DropShelf/FileItemView.swift) - individual file visualization
- [DropTargetView.swift](DropShelf/DropTargetView.swift) - drag and drop target area
- [DragDetector.swift](DropShelf/DragDetector.swift) - mouse shake detector
- [CloseButton.swift](DropShelf/CloseButton.swift) - file removal button

## License

MIT
