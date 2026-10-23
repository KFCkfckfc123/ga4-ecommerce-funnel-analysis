"""Run the presentation notebook in a fresh kernel and preserve its outputs."""
from pathlib import Path
import nbformat
from nbclient import NotebookClient

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'notebooks/01_ga4_data_quality.ipynb'
notebook = nbformat.read(path, as_version=4)
NotebookClient(
    notebook, timeout=180, kernel_name='python3',
    resources={'metadata': {'path': str(path.parent)}},
).execute()
nbformat.validate(notebook)
nbformat.write(notebook, path)
print('Executed and saved all notebook cells successfully.')
