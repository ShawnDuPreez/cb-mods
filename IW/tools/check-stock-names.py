"""Checks the stock names a custom GSC script uses against a decompile of the game's scripts.

Usage: check-stock-names.py <decompiled dir> <script.gsc>...

<decompiled dir> is the "decompiled" folder of github.com/mjkzy/iw7-gsc-dump.

A misspelt stock name compiles fine and reads undefined in the game, so this
looks for two kinds of slip:

  1. scripts\\path\\file::function  the file must exist in the decompile and
                                   define that function
  2. .field                        a field the script reads or calls must
                                   appear somewhere in the decompile, unless
                                   the script itself assigns it

Prints every problem and exits 1 if there is one.
"""
import pathlib
import re
import subprocess
import sys

dump = pathlib.Path(sys.argv[1])
problems = 0

for path in sys.argv[2:]:
    text = pathlib.Path(path).read_text()
    code = re.sub(r"//[^\n]*", "", text)
    code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', code)
    own_functions = set(re.findall(r"^([a-z_][a-z0-9_]*)\s*\(", code, re.M))

    for file, function in sorted(set(re.findall(r"(scripts(?:\\[a-z0-9_]+)+)::([a-z_][a-z0-9_]*)", code, re.I))):
        stock = dump / (file.replace("\\", "/") + ".gsc")
        if not stock.is_file():
            print(f"{path}: no stock file for {file}")
            problems += 1
            continue
        if not re.search(r"^" + re.escape(function) + r"\s*\(", stock.read_text(errors="replace"), re.M):
            print(f"{path}: {file} has no function {function}")
            problems += 1

    assigned = set(re.findall(r"\.([a-z_][a-z0-9_]*)\s*(?:\[[^\]]*\]\s*)?=[^=]", code, re.I))
    fields = set(re.findall(r"[a-z0-9_\])]\.([a-z_][a-z0-9_]*)", code, re.I))
    for field in sorted(fields - assigned):
        found = subprocess.run(
            ["grep", "-rqE", "--include=*.gsc", r"\." + re.escape(field) + r"([^A-Za-z0-9_]|$)", str(dump)],
            stdout=subprocess.DEVNULL,
        ).returncode == 0
        if not found:
            print(f"{path}: field .{field} is not in the decompile and is not assigned in this script")
            problems += 1

    print(f"{path}: checked")

sys.exit(1 if problems else 0)
