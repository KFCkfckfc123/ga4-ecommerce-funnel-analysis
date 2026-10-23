"""Inspect the public project for untranslated text and private references."""
from pathlib import Path
import json
import re
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CJK = re.compile(r'[\u3400-\u9fff]')
PRIVATE = re.compile(r'/Users/|/workspace/|libfile_|file_000000', re.I)
SECRETS = re.compile(r'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')
failures = []

def inspect(label, text):
    # The scanner's own patterns are literals, not leaked data.
    for kind, pattern in [('Chinese text', CJK), ('private reference', PRIVATE), ('credential', SECRETS)]:
        if pattern.search(text):
            failures.append(f'{label}: {kind}')

for path in sorted(ROOT.rglob('*')):
    if not path.is_file() or any(p in {'.git', '.venv', '__pycache__', '.ipynb_checkpoints'} for p in path.parts):
        continue
    rel = path.relative_to(ROOT)
    if CJK.search(str(rel)):
        failures.append(f'{rel}: non-English filename')
    if path.name.startswith('.~') or path.suffix == '.twbr':
        failures.append(f'{rel}: temporary workbook file')
    if path.name == Path(__file__).name:
        continue
    if path.suffix in {'.md', '.sql', '.csv', '.tsv', '.txt', '.json', '.py', '.twb', '.ipynb'} or path.name == '.gitignore':
        inspect(str(rel), path.read_text())
    if path.suffix == '.twbx':
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None
            for name in z.namelist():
                assert not Path(name).is_absolute() and '..' not in Path(name).parts
                if name.endswith(('.twb', '.csv')):
                    inspect(f'{rel}!{name}', z.read(name).decode())
                if name.endswith('.twb'):
                    tree = ET.fromstring(z.read(name))
                    for node in tree.iter():
                        for key, value in node.attrib.items():
                            if key.lower() in {'password', 'access-token', 'refresh-token'} and value:
                                failures.append(f'{rel}: populated connection secret')

assert not failures, '\n'.join(failures)
print(json.dumps({'status': 'PASS', 'checks': ['English text and filenames', 'private references', 'common credentials', 'package XML and connection secrets']}, indent=2))
