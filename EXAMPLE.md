# Example Usage

This file demonstrates how to use emacs-tyche with a simple Python Hypothesis test.

## Setup

1. Install the package and dependencies:
   ```elisp
   ;; Add to your Emacs config
   (add-to-list 'load-path "/path/to/emacs-tyche")
   (require 'tyche)
   
   ;; Install websocket package if needed
   M-x package-install RET websocket RET
   ```

2. Configure (optional):
   ```elisp
   ;; Use the deployed web view (default)
   (setq tyche-webview-url "https://tyche-pbt.github.io/tyche-extension/")
   
   ;; Or use a local development server
   ;; (setq tyche-webview-url "http://localhost:3000")
   
   ;; Change WebSocket port if needed
   ;; (setq tyche-websocket-port 8181)
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

The Tyche web view will show:

- **Distribution of test inputs**: Visual representation of the values Hypothesis generated
- **Event data**: Visualizations of the events you logged (list lengths, etc.)
- **Target metrics**: Information about optimization targets
- **Coverage data**: If available, code coverage information

## Commands to remember

- `M-x tyche-activate` - Start watching for test results
- `M-x tyche-refresh` - Manually reload all observation files
- `M-x tyche-open-webview` - Reopen the web view if you closed it
- `M-x tyche-deactivate` - Stop watching (cleans up file watchers and WebSocket server)

## Troubleshooting

### Web view doesn't show data

1. Check that observation files were created:
   ```bash
   ls -la .hypothesis/observed/
   ```

2. Manually refresh: `M-x tyche-refresh`

3. Check the *Messages* buffer for errors

### WebSocket connection fails

1. Check the Messages buffer: `M-x view-echo-area-messages`
2. Verify the WebSocket server started (should see "WebSocket server started on port 8181")
3. Try a different port if 8181 is in use:
   ```elisp
   (setq tyche-websocket-port 8282)
   ```
4. Restart: `M-x tyche-deactivate` then `M-x tyche-activate`

### Browser issues

If the web view doesn't open:
- Manually open the URL in your browser
- Default: `https://tyche-pbt.github.io/tyche-extension/`
- Or your configured `tyche-webview-url`

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
