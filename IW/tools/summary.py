"""Summarise one test-server run.

Usage: summary.py <log file> <line prefix> <script name>... [-v]

Prints every log line that starts with <line prefix> (the debug script's own
output), then counts script runtime errors. Errors raised inside one of the
given scripts are the mod's own bugs. Errors raised in the game's scripts
while one of the given scripts was the caller are listed apart: with bots
most of those come from the game expecting a real player's profile and
weapons. -v lists every kind of script error.
"""
import collections
import re
import sys

args = [a for a in sys.argv[1:] if a != "-v"]
verbose = "-v" in sys.argv
path, prefix, names = args[0], args[1], args[2:]
lines = open(path, errors="replace").read().split("\n")

for line in lines:
    if "compile error" in line or "failed to compile" in line:
        print("!!", line[:400])

for line in lines:
    if line.startswith(prefix):
        print(line.rstrip()[:300])

blocks = collections.Counter()
i = 0
while i < len(lines):
    if "script runtime error" in lines[i]:
        j = i + 1
        block = []
        while j < len(lines) and "**********" not in lines[j] and not lines[j].startswith(prefix) and len(block) < 8:
            if lines[j].strip():
                block.append(re.sub(r"0x[0-9a-f]+", "0x..", lines[j].strip()))
            j += 1
        blocks[" | ".join(block)] += 1
        i = j
    else:
        i += 1

def raised_in(block):
    """The file of the innermost frame: where the error was raised."""
    for part in block.split(" | "):
        found = re.search(r'at function "[^"]*" in file "([^"]+)"', part)
        if found:
            return found.group(1)
    return ""


inside = {k: n for k, n in blocks.items() if any(name in raised_in(k) for name in names)}
through = {k: n for k, n in blocks.items() if k not in inside and any(name in k for name in names)}
print(f"script errors: {sum(blocks.values())} total in {len(blocks)} kinds")
print(f"  raised inside {', '.join(names)}: {sum(inside.values())}")
for k, n in inside.items():
    print("    MOD ERROR x%d: %s" % (n, k[:700]))
print(f"  raised in the game's own scripts while called from those files: {sum(through.values())}")
for k, n in through.items():
    print("    x%d: %s" % (n, k[:330]))
if verbose:
    for k, n in blocks.most_common(60):
        print("  x%d %s" % (n, k[:400]))
