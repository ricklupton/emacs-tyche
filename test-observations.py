#!/usr/bin/env python3
"""
Simple test script to verify emacs-tyche functionality.
This creates test observation files that emacs-tyche should detect.
"""

import os
import json
import time
from pathlib import Path

def create_test_observations():
    """Create test observation files in .hypothesis/observed/"""
    # Create the directory
    obs_dir = Path(".hypothesis/observed")
    obs_dir.mkdir(parents=True, exist_ok=True)
    
    # Create a test observation file
    test_file = obs_dir / "test_example.jsonl"
    
    print(f"Creating test observation file: {test_file}")
    
    # Write some example JSONL data
    observations = [
        {
            "type": "test_case",
            "run_start": 1234567890.0,
            "property": "test_example",
            "status": "passed",
        },
        {
            "type": "draw",
            "value": [1, 2, 3],
            "kwargs": {},
        },
        {
            "type": "event",
            "title": "list_length",
            "payload": 3,
        },
        {
            "type": "draw",
            "value": [],
            "kwargs": {},
        },
        {
            "type": "event",
            "title": "list_length",
            "payload": 0,
        },
        {
            "type": "event",
            "title": "is_empty",
            "payload": True,
        },
    ]
    
    with open(test_file, 'w') as f:
        for obs in observations:
            f.write(json.dumps(obs) + '\n')
    
    print(f"✓ Created {test_file} with {len(observations)} observations")
    return test_file

def update_test_observations(test_file):
    """Append more observations to test file watching"""
    print(f"\nAppending to {test_file}...")
    
    new_observations = [
        {
            "type": "draw",
            "value": [5, 6, 7, 8, 9],
            "kwargs": {},
        },
        {
            "type": "event",
            "title": "list_length",
            "payload": 5,
        },
    ]
    
    with open(test_file, 'a') as f:
        for obs in new_observations:
            f.write(json.dumps(obs) + '\n')
    
    print(f"✓ Appended {len(new_observations)} observations")

def main():
    print("=== Emacs-Tyche Test Observation Generator ===\n")
    
    # Create initial observations
    test_file = create_test_observations()
    
    print("\n✓ Initial observations created!")
    print("\nNow run in Emacs:")
    print("  M-x tyche-activate")
    print("\nThe package should:")
    print("  1. Start a WebSocket server")
    print("  2. Load the existing observation file")
    print("  3. Open the web view in your browser")
    print("  4. Watch for changes to the observation files")
    
    # Wait for user to activate Tyche
    input("\nPress Enter to append more observations (to test file watching)...")
    
    # Update observations
    update_test_observations(test_file)
    
    print("\n✓ File updated! The Tyche web view should update automatically.")
    print("\nYou can verify in Emacs *Messages* buffer that it detected the change.")
    print("\nClean up:")
    print("  M-x tyche-deactivate")
    print("  rm -rf .hypothesis/")

if __name__ == "__main__":
    main()
