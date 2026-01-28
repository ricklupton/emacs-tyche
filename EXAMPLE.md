# Example Usage

This file demonstrates how to use emacs-tyche with a simple Python Hypothesis test.

## Setup

1. Install the package and dependencies:
   ```elisp
   ;; Add to your Emacs config
   (add-to-list 'load-path "/path/to/emacs-tyche")
   (require 'tyche)
   
   ;; Install required packages if needed
   M-x package-install RET websocket RET
   M-x package-install RET simple-httpd RET
   ```

2. Configure (optional):
   ```elisp
   ;; Change HTTP server port if needed (default: 8182)
   ;; (setq tyche-http-port 8182)
   
   ;; Change WebSocket port if needed (default: 8181)
   ;; (setq tyche-websocket-port 8181)
   
   ;; Adjust debounce delay (default: 0.6 seconds)
   ;; (setq tyche-debounce-delay 0.6)
   ```

## Example Python test with Hypothesis

Create a file `test_example.py`:

```python
from hypothesis import given, strategies as st, event, target

@given(st.lists(st.integers()))
def test_list_operations(lst):
    # Add observability events
    event("list_length", payload=len(lst))
    event("is_empty", payload=len(lst) == 0)
    
    # Add target metrics (for optimization)
    target(float(len(lst)))
    
    # Your actual test
    reversed_twice = list(reversed(list(reversed(lst))))
    assert reversed_twice == lst

@given(st.integers(min_value=0, max_value=100))
def test_square_root(n):
    event("input_value", payload=n)
    
    import math
    sqrt = math.sqrt(n)
    
    # Square root should always be non-negative
    assert sqrt >= 0
    
    # Squaring the result should give approximately the original number
    assert abs(sqrt * sqrt - n) < 1e-10
```

## Running with Tyche

### Method 1: Activate first, then run tests

1. Open your project in Emacs
2. Run `M-x tyche-activate`
3. In a terminal, run:
   ```bash
   HYPOTHESIS_EXPERIMENTAL_OBSERVABILITY=1 pytest test_example.py -v
   ```
4. Watch the Tyche web view update automatically!

### Method 2: Run tests first, then activate

1. Run your tests with observability enabled:
   ```bash
   HYPOTHESIS_EXPERIMENTAL_OBSERVABILITY=1 pytest test_example.py -v
   ```
2. In Emacs, run `M-x tyche-activate`
3. The existing results will be loaded immediately

## What you'll see

When you activate Tyche, you'll see:

1. **Connection Status**: A green "Connected" indicator in the top-right of the web page
2. **Tyche UI**: The full Tyche visualization interface with:
   - **Distribution of test inputs**: Visual representation of the values Hypothesis generated
   - **Event data**: Visualizations of the events you logged (list lengths, etc.)
   - **Target metrics**: Information about optimization targets
   - **Coverage data**: If available, code coverage information

The wrapper page automatically connects to the Emacs WebSocket server and displays real-time connection status.

## Commands to remember

- `M-x tyche-activate` - Start HTTP + WebSocket servers and open web view
- `M-x tyche-refresh` - Manually reload all observation files
- `M-x tyche-open-webview` - Reopen the web view if you closed it
- `M-x tyche-deactivate` - Stop all servers and clean up resources

## Troubleshooting

### Connection status shows "Disconnected"

1. Check the *Messages* buffer for errors: `M-x view-echo-area-messages`
2. Verify WebSocket server started (should see "WebSocket server started on port 8181")
3. Check if ports are available (not used by other processes)
4. Try different ports:
   ```elisp
   (setq tyche-http-port 8282)
   (setq tyche-websocket-port 8281)
   ```
5. Restart: `M-x tyche-deactivate` then `M-x tyche-activate`

### Web view doesn't show data

1. Check that observation files were created:
   ```bash
   ls -la .hypothesis/observed/
   ```

2. Manually refresh: `M-x tyche-refresh`

3. Check the *Messages* buffer for errors
4. Look at browser console for JavaScript errors

### HTTP server issues

If the browser shows "connection refused":
1. Check if HTTP server started (should see "HTTP server started on port 8182")
2. Verify the webview directory exists
3. Check for port conflicts
4. Try manually: `http://localhost:8182/index.html?wsPort=8181`

### Browser issues

If the web view doesn't open automatically:
- Manually open: `http://localhost:8182/index.html?wsPort=8181`
- Check your default browser is set correctly
- The page embeds the Tyche UI from `https://tyche-pbt.github.io/tyche-extension`

## Advanced: Custom observation globs

If you're using a different directory structure:

```elisp
(setq tyche-observation-globs
      '("**/custom-dir/observations/*.jsonl"
        "**/.hypothesis/observed/*.jsonl"))
```

## Advanced: Multiple projects

You can activate Tyche for different projects by calling `tyche-activate` with different project roots:

```elisp
;; Activate for a specific project
(tyche-activate "/path/to/project1")

;; Switch to another project
(tyche-deactivate)
(tyche-activate "/path/to/project2")
```

The package will automatically detect the project root when you call `M-x tyche-activate` interactively.
