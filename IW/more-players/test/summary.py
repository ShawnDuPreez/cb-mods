"""Summarise one bot-test run: the test output, and script errors that come from the mod's files.
Usage: summary.py <log file> [-v]   (-v lists every kind of script error)"""
import re, collections, sys
lines = open(sys.argv[1], errors='replace').read().split('\n')
for l in lines:
    if 'compile error' in l or 'failed to compile' in l: print('!!', l[:300])
show = False
for l in lines:
    if l.startswith('[mpdbg] TEST') or l.startswith('[mpdbg] DONE') or 'never became' in l or 'failed' in l and 'mpdbg' in l: show = True; print(l.rstrip()[:240]); continue
    if l.startswith('[mpdbg]   ') and show: print(l.rstrip()[:240]); continue
    show = False
blocks = collections.Counter(); i = 0
while i < len(lines):
    if 'script runtime error' in lines[i]:
        j = i + 1; blk = []
        while j < len(lines) and '**********' not in lines[j] and not lines[j].startswith('[mpdbg]') and len(blk) < 6:
            if lines[j].strip(): blk.append(re.sub(r'0x[0-9a-f]+', '0x..', lines[j].strip()))
            j += 1
        blocks[' | '.join(blk)] += 1; i = j
    else: i += 1
mine = {k: n for k, n in blocks.items() if 'custom_scripts/cp/more_players' in k or 'custom_scripts/cp/scoreboard' in k}
print(f'script errors: {sum(blocks.values())} total in {len(blocks)} kinds; in the mod\'s files: {sum(mine.values())}')
for k, n in mine.items(): print('  MOD ERROR x%d: %s' % (n, k[:600]))
if '-v' in sys.argv:
    for k, n in blocks.most_common(40): print('  x%d %s' % (n, k[:330]))
