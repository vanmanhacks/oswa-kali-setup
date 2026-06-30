#!/usr/bin/env python3
"""Split an OSWA exam notes file into one .md per finding.

Delimiter: \\n# Title\\n — splits on the mdfindings2reptor section header.
Preamble (targets, commands, etc.) before the first finding is discarded.
Output files are numbered f01.md, f02.md, ... in original document order.
"""
import os, sys

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <notes-file.md>")
    sys.exit(1)

text = open(sys.argv[1]).read()
parts = text.split('\n# Title\n')

outdir = 'findings'
os.makedirs(outdir, exist_ok=True)

for i, part in enumerate(parts[1:], 1):
    path = f'{outdir}/f{i:02d}.md'
    with open(path, 'w') as f:
        f.write('# Title\n' + part)

print(f"Wrote {len(parts)-1} findings to {outdir}/")
