#!/usr/bin/env python3
import json, subprocess, sys

def run_js(code):
    # Wrap code
    full_script = f'''tell application "Google Chrome"
        tell front window's active tab
            execute javascript "{code}"
        end tell
    end tell'''
    res = subprocess.run(['osascript', '-e', full_script], capture_output=True, text=True)
    if res.returncode != 0:
        print("ERROR:", res.stderr.strip())
        return None
    return res.stdout.strip()

if __name__ == '__main__':
    # Inspect all inputs and textareas
    js = """
    (function() {
        var items = [];
        var all = document.querySelectorAll('input, textarea');
        for (var i = 0; i < all.length; i++) {
            var el = all[i];
            items.push({
                idx: i,
                tag: el.tagName,
                type: el.type,
                aria: el.getAttribute('aria-label') || '',
                id: el.id || '',
                name: el.name || '',
                val: (el.value || '').substring(0, 40)
            });
        }
        return JSON.stringify(items);
    })()
    """
    # Escape quotes for AppleScript
    escaped = js.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ')
    out = run_js(escaped)
    print("OUTPUT:", out)
