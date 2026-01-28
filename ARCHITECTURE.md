# Architecture

This document explains the architecture of emacs-tyche and how it integrates with the Tyche visualization tool.

## Overview

The emacs-tyche package provides Emacs integration for Tyche, a property-based testing visualization tool. The architecture is designed to mirror the VS Code extension while working entirely within Emacs' capabilities.

## Components

### 1. Emacs Backend (`tyche.el`)

The Emacs Lisp package provides:

- **File Watchers**: Uses `filenotify` to monitor observation directories (`.hypothesis/observed/`, `.quickcheck/observations/`)
- **WebSocket Server**: Runs on port 8181 (configurable) using the `websocket.el` library
- **HTTP Server**: Runs on port 8182 (configurable) using the `simple-httpd` library
- **Data Processing**: Reads JSONL observation files, aggregates them, and debounces changes

### 2. Custom HTML Wrapper (`webview/index.html`)

A lightweight HTML page that:

- Connects to the Emacs WebSocket server
- Embeds the Tyche web UI in an iframe
- Forwards data from WebSocket to the Tyche UI via `postMessage`
- Displays connection status
- Handles reconnection automatically

### 3. Tyche Web UI

The official Tyche React application (from `tyche-extension` submodule) that:

- Visualizes property-based testing data
- Shows distributions, events, targets, and coverage
- Provides interactive exploration of test results

## Communication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         Emacs Process                            │
│                                                                  │
│  ┌──────────────────┐        ┌─────────────────┐               │
│  │  File Watchers   │───────▶│  Data Processor │               │
│  └──────────────────┘        └────────┬────────┘               │
│          │                             │                         │
│          │ (Detect changes)            │ (Aggregate JSONL)       │
│          ▼                             ▼                         │
│  ┌──────────────────────────────────────────────┐               │
│  │         WebSocket Server (port 8181)          │               │
│  └──────────────────────┬───────────────────────┘               │
│                         │                                        │
│  ┌──────────────────────┴───────────────────────┐               │
│  │         HTTP Server (port 8182)               │               │
│  │         Serves: webview/index.html            │               │
│  └──────────────────────┬───────────────────────┘               │
└─────────────────────────┼────────────────────────────────────────┘
                          │
                          │ HTTP (serve wrapper)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Web Browser                               │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Wrapper Page (index.html)                     │  │
│  │                                                            │  │
│  │  ┌──────────────────┐      ┌──────────────────────────┐  │  │
│  │  │  WebSocket Client │──────▶│  Status Indicator       │  │  │
│  │  └────────┬─────────┘      └──────────────────────────┘  │  │
│  │           │                                               │  │
│  │           │ (Receive JSONL data)                          │  │
│  │           ▼                                               │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │              postMessage Forwarder                   │ │  │
│  │  └────────┬────────────────────────────────────────────┘ │  │
│  │           │                                               │  │
│  │           │ postMessage({command: 'load-data', lines})    │  │
│  │           ▼                                               │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │                                                      │ │  │
│  │  │        IFrame: Tyche React Application              │ │  │
│  │  │        (from tyche-extension or GitHub.io)           │ │  │
│  │  │                                                      │ │  │
│  │  │  - Parses JSONL observations                         │ │  │
│  │  │  - Builds interactive visualizations                 │ │  │
│  │  │  - Shows distributions, events, coverage             │ │  │
│  │  │                                                      │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Message Format

### WebSocket → Wrapper

Raw JSONL data (concatenated observation files):

```
{"type": "test_case", "run_start": 1234567890.0, ...}
{"type": "draw", "value": [1, 2, 3], ...}
{"type": "event", "title": "list_length", "payload": 3}
```

### Wrapper → Tyche UI (postMessage)

```javascript
{
  command: 'load-data',
  lines: '{"type": "test_case", ...}\n{"type": "draw", ...}\n...'
}
```

This matches the VS Code extension's message format exactly.

## Comparison with VS Code Extension

| Feature | VS Code Extension | emacs-tyche |
|---------|-------------------|-------------|
| **UI Hosting** | VS Code Webview API | HTTP server + browser |
| **Communication** | `postMessage` (built-in) | WebSocket + postMessage |
| **File Watching** | VS Code file watcher API | Emacs `filenotify` |
| **Data Format** | JSONL observations | JSONL observations (same) |
| **Message Protocol** | `{command: 'load-data', lines}` | `{command: 'load-data', lines}` (same) |
| **Offline Support** | Bundled in extension | Served via local HTTP |

## Design Decisions

### Why HTTP Server + WebSocket?

1. **Separation of Concerns**: HTTP serves static files, WebSocket handles real-time data
2. **Browser Compatibility**: Standard web technologies work in any browser
3. **Offline Operation**: No external dependencies once installed
4. **VS Code Compatibility**: Can use the same Tyche UI without modification

### Why Not Pure WebSocket?

WebSocket alone cannot serve HTML files to the browser. We need HTTP to:
- Serve the initial wrapper HTML page
- Load JavaScript and CSS resources
- Enable standard browser navigation

### Why Not Long Polling?

While long polling was considered, WebSocket provides:
- True bi-directional communication
- Lower latency for real-time updates
- Standard protocol that browsers handle well
- Simpler state management

### Why Custom Wrapper Instead of Direct Tyche UI?

The wrapper provides:
- WebSocket client (Tyche UI doesn't have one)
- Connection status and error handling
- Message format adaptation
- Flexibility to use deployed or local Tyche UI

## Configuration

### Ports

- **HTTP Server**: 8182 (configurable via `tyche-http-port`)
- **WebSocket Server**: 8181 (configurable via `tyche-websocket-port`)

Different ports avoid conflicts and allow independent operation.

### Tyche UI Source

The wrapper can load the Tyche UI from:

1. **Deployed version** (default): `https://tyche-pbt.github.io/tyche-extension`
   - No build required
   - Always up-to-date
   - Requires internet on first load (cached after)

2. **Local build**: `http://localhost:3000`
   - Full control over version
   - For development
   - Requires building tyche-extension submodule

The URL is passed via query parameter to the wrapper page.

## Error Handling

1. **Missing Dependencies**: Soft warnings when websocket.el or simple-httpd not available
2. **Connection Failures**: Wrapper shows status and auto-reconnects
3. **File System Errors**: Logged to Emacs *Messages* buffer
4. **Port Conflicts**: Clear error messages with configuration hints

## Security

- **Localhost Only**: Both servers bind to localhost (not exposed to network)
- **No Authentication**: Not needed since servers are local-only
- **Origin Validation**: Wrapper validates postMessage origins to prevent malicious iframe injection
- **Secure Messaging**: postMessage uses explicit target origin, not wildcard (*)
- **CORS**: Wrapper uses iframe + postMessage (secure cross-origin communication)
- **Input Validation**: Shell commands properly escaped, files validated before reading

## Known Limitations

1. **Global HTTP Server**: simple-httpd uses global variables (`httpd-root`, `httpd-port`), so only one HTTP server can run at a time in Emacs. This may conflict with other packages using simple-httpd.

2. **Single Project**: Currently supports watching one project at a time. Activating for a new project automatically deactivates the previous one.

3. **Browser Dependency**: Requires a web browser to display the UI (cannot use EWW due to WebSocket limitations).

4. **Internet for First Load**: The Tyche UI iframe loads from GitHub.io, requiring internet connection on first access (cached afterward).

## Performance

- **Debouncing**: 600ms delay prevents excessive processing during rapid file changes
- **Lazy Loading**: Observation files only read when changed
- **Efficient Transfer**: Raw JSONL sent once, parsed once in browser
- **Connection Pooling**: WebSocket connection reused for multiple updates

## Future Enhancements

Possible improvements:

1. **Bundled Tyche UI**: Pre-build and bundle the Tyche React app
2. **Multiple Projects**: Support watching multiple projects simultaneously
3. **EWW Integration**: Display UI directly in Emacs using EWW browser
4. **History**: Store and replay previous test runs
5. **Filtering**: Server-side filtering of observations
