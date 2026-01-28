# emacs-tyche

Emacs integration for [Tyche](https://github.com/tyche-pbt/tyche-extension), a tool that helps developers understand the effectiveness of their property-based tests.

## Overview

Tyche works with property-based testing frameworks like:
- [Python's Hypothesis](https://hypothesis.readthedocs.io/en/latest/)
- [Haskell's QuickCheck](https://hackage.haskell.org/package/QuickCheck)
- [Java's JQF](https://github.com/rohanpadhye/JQF)
- [Coq's QuickChick](https://github.com/QuickChick/QuickChick)

This Emacs package provides similar functionality to the [VS Code extension](https://github.com/tyche-pbt/tyche-extension), allowing you to visualize property-based test results directly from Emacs.

## Features

- **Automatic file watching**: Monitors `.hypothesis/observed/` and `.quickcheck/observations/` directories for changes
- **WebSocket server**: Communicates with the Tyche web UI via WebSocket
- **Live updates**: Automatically sends new test observations to the web view
- **Project-based activation**: Easy to enable/disable per project

## Installation

### Prerequisites

- Emacs 27.1 or later
- [websocket.el](https://github.com/ahyatt/emacs-websocket) package

### Installing from source

1. Clone this repository:
   ```bash
   git clone --recursive https://github.com/ricklupton/emacs-tyche.git
   ```

2. Add to your Emacs configuration:
   ```elisp
   (add-to-list 'load-path "/path/to/emacs-tyche")
   (require 'tyche)
   ```

3. Install the `websocket` package if not already installed:
   ```elisp
   M-x package-install RET websocket RET
   ```

## Usage

### Basic workflow

1. **Activate Tyche for your project**:
   ```
   M-x tyche-activate
   ```
   This will:
   - Start a WebSocket server on port 8181 (configurable)
   - Begin watching for observation files
   - Open the Tyche web view in your browser

2. **Run your property-based tests**:
   - For Hypothesis (Python):
     ```bash
     HYPOTHESIS_EXPERIMENTAL_OBSERVABILITY=1 pytest your_test.py
     ```
   - The package will automatically detect new observation files and send them to the web view

3. **Deactivate when done**:
   ```
   M-x tyche-deactivate
   ```

### Available commands

- `M-x tyche-activate` - Activate Tyche for the current project
- `M-x tyche-deactivate` - Deactivate Tyche
- `M-x tyche-refresh` - Manually reload all observation files
- `M-x tyche-open-webview` - Open/reopen the web view

## Configuration

Customize Tyche behavior with these variables:

```elisp
;; WebSocket port (default: 8181)
(setq tyche-websocket-port 8181)

;; Observation file glob patterns
(setq tyche-observation-globs
      '("**/.hypothesis/observed/*.jsonl"
        "**/.quickcheck/observations/*.jsonl"))

;; Web view URL
;; Use local development server:
(setq tyche-webview-url "http://localhost:3000")
;; Or use the deployed version:
(setq tyche-webview-url "https://tyche-pbt.github.io/tyche-extension/")
```

## Setting up the web view

This package includes the Tyche web UI as a submodule. You have two options:

### Option 1: Use the deployed web view (easiest)

The default configuration uses the deployed version at `https://tyche-pbt.github.io/tyche-extension/`, which should work out of the box.

### Option 2: Run the web view locally

For development or if you prefer a local setup:

1. Navigate to the submodule:
   ```bash
   cd tyche-extension
   ```

2. Install dependencies:
   ```bash
   npm run install:all
   ```

3. Build the observability tools:
   ```bash
   npm run build:observability-tools
   ```

4. Start the development server:
   ```bash
   npm run start:webview
   ```

5. Configure Emacs to use the local server:
   ```elisp
   (setq tyche-webview-url "http://localhost:3000")
   ```

## How it works

1. When you activate Tyche, the package:
   - Starts a WebSocket server that the web view can connect to
   - Sets up file system watchers for observation directories
   - Loads any existing observation files

2. When test files are created/modified:
   - The file watcher detects changes
   - After a brief debounce period (600ms), the package reads the JSONL files
   - The content is sent to all connected WebSocket clients

3. The web view:
   - Connects to the WebSocket server
   - Receives observation data
   - Visualizes the property-based testing results

## Using with Hypothesis

To use Tyche with Python's Hypothesis framework:

1. Enable observability when running tests:
   ```bash
   HYPOTHESIS_EXPERIMENTAL_OBSERVABILITY=1 pytest
   ```

2. Add features to your tests using `event` and `target`:
   ```python
   from hypothesis import given, strategies as st, event

   @given(st.lists(st.integers()))
   def test_example(l):
       event("list_length", payload=len(l))
       assert len(l) >= 0
   ```

3. Run `M-x tyche-activate` before or after running tests

4. View the results in the web UI

## Troubleshooting

### WebSocket connection issues

If the web view can't connect:
- Check that the WebSocket server started: look for "WebSocket server started on port 8181" in messages
- Verify no firewall is blocking port 8181
- Try a different port: `(setq tyche-websocket-port 8182)` and restart

### No observations appearing

- Verify observation files exist in `.hypothesis/observed/` or `.quickcheck/observations/`
- Check that files have `.jsonl` extension
- Try `M-x tyche-refresh` to manually reload
- Look for error messages in the `*Messages*` buffer

### Web view not opening

- Check your `tyche-webview-url` setting
- Try opening manually in a browser
- If using local development server, ensure it's running with `npm run start:webview`

## Development

To contribute or modify this package:

1. Clone with submodules:
   ```bash
   git clone --recursive https://github.com/ricklupton/emacs-tyche.git
   ```

2. Make changes to `tyche.el`

3. Test in Emacs:
   ```elisp
   M-x load-file RET tyche.el RET
   ```

## License

GPL-3.0 or later. See LICENSE file for details.

The Tyche web UI (in the `tyche-extension` submodule) has its own license.

## Credits

- Tyche and the VS Code extension: [Harrison Goldstein](https://github.com/hgoldstein95) and contributors
- Emacs integration: [Rick Lupton](https://github.com/ricklupton)

## References

- [Tyche VS Code Extension](https://github.com/tyche-pbt/tyche-extension)
- [Tyche Paper (UIST'24)](https://harrisongoldste.in/papers/uist24-tyche.pdf)
- [Hypothesis Observability API](https://hypothesis.readthedocs.io/en/latest/observability.html)
