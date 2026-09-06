"""Restore required feature dex before zip-alignment/signing; no signing secrets."""
import argparse
import zipfile
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('input', type=Path)
p.add_argument('output', type=Path)
p.add_argument('feature_dex', type=Path)
p.add_argument('connection_dex', type=Path)
a = p.parse_args()
if a.input.resolve() == a.output.resolve():
    p.error('Output must differ from input')
with zipfile.ZipFile(a.input) as source, zipfile.ZipFile(a.output, 'w') as target:
    for entry in source.infolist():
        if entry.filename in ('smali_classes7-feature.dex', 'classes7.dex', 'classes8.dex'):
            continue
        target.writestr(entry, source.read(entry))
    for name, path in [('classes7.dex', a.feature_dex), ('classes8.dex', a.connection_dex)]:
        data = path.read_bytes()
        if not data.startswith(b'dex\n'):
            raise ValueError(f'{name} is not DEX')
        target.writestr(name, data, compress_type=zipfile.ZIP_STORED)
