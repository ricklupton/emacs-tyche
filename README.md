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
- **HTTP server**: Serves the Tyche web UI locally for offline use
- **WebSocket server**: Communicates with the web UI via WebSocket for real-time updates
- **Live updates**: Automatically sends new test observations to the web view
- **Project-based activation**: Easy to enable/disable per project
- **Bundled UI**: Works offline without requiring external dependencies

## Installation

### Prerequisites

- Emacs 27.1 or later
- [websocket.el](https://github.com/ahyatt/emacs-websocket) package
- [simple-httpd](https://github.com/skeeto/emacs-web-server) package

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

3. Install the required packages if not already installed:
   ```elisp
   M-x package-install RET websocket RET
   M-x package-install RET simple-httpd RET
   ```

## Usage

### Basic workflow

1. **Activate Tyche for your project**:
   ```
   M-x tyche-activate
   ```
   This will:
   - Start an HTTP server on port 8182 (configurable) to serve the web UI
   - Start a WebSocket server on port 8181 (configurable) for data communication
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
;; HTTP server port (default: 8182)
(setq tyche-http-port 8182)

;; WebSocket port (default: 8181)
(setq tyche-websocket-port 8181)

;; Observation file glob patterns
(setq tyche-observation-globs
      '("**/.hypothesis/observed/*.jsonl"
        "**/.quickcheck/observations/*.jsonl"))

;; File change debounce delay in seconds (default: 0.6)
(setq tyche-debounce-delay 0.6)
```

## How it works

The emacs-tyche package creates a local web server architecture similar to the VS Code extension:

1. **HTTP Server** (port 8182): Serves a custom HTML page (`webview/index.html`) that acts as a wrapper
2. **WebSocket Server** (port 8181): Sends observation data to the web UI in real-time
3. **Wrapper Page**: Connects to the WebSocket server and embeds the Tyche web UI in an iframe
4. **Message Forwarding**: The wrapper receives data via WebSocket and forwards it to the Tyche UI using `postMessage`

This architecture:
- Works completely offline (no external dependencies once installed)
- Mirrors the VS Code extension's messaging pattern
- Allows the Tyche UI to work without modification
- Provides clear connection status and error handling

## Workflow

1. When you activate Tyche, the package:
   - Starts an HTTP server to serve the custom wrapper page
   - Starts a WebSocket server for data communication
   - Sets up file system watchers for observation directories
   - Loads any existing observation files
   - Opens the web UI in your browser

2. When test files are created/modified:
   - The file watcher detects changes
   - After a brief debounce period (600ms), the package reads the JSONL files
   - The content is sent to all connected WebSocket clients
   - The wrapper page receives the data and forwards it to the Tyche UI

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

- Check your `tyche-http-port` setting
- Try opening manually: `http://localhost:8182/index.html?wsPort=8181`
- If port 8182 is in use, try a different port: `(setq tyche-http-port 8282)`

### Port conflicts

If you get "Port may be in use" errors:
- Choose different ports for HTTP and WebSocket servers
- Note: simple-httpd uses global variables, so only one HTTP server can run at a time in Emacs
- Deactivate Tyche before using simple-httpd for other purposes

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
