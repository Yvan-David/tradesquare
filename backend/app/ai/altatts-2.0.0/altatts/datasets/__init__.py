"""
``altatts.datasets`` -- turn many heterogeneous TTS corpora into ONE
versioned, clean, uniformly formatted training set.

    registry.py   the list of source datasets (DatasetSpec) -- add new ones here
    adapters.py   readers for every source format (csv/tsv/json/parquet/xlsx/...)
    combine.py    the pipeline: load -> validate -> analyse -> clean -> balance
                  -> gender -> split -> convert audio -> write manifests + report
    stats.py      statistics and the markdown/JSON report
    cli.py        ``altatts combine-data``

Output folder (versioned; re-running replaces the previous version):

    <out>/VERSION.json          version number, date, sources, counts, options
    <out>/train.jsonl dev.jsonl test.jsonl     ALTATTS metadata (one line per clip)
    <out>/audio/<dataset>/*.flac               22.05 kHz mono FLAC, uniform
    <out>/report.md report.json stats/*.json   per-dataset + total statistics
    <out>/samples/<dataset>/                   3 clips per dataset to listen to
    <out>/speakers.json config.json            speaker table, options used
"""
from .spec import DatasetSpec, Record                       # noqa: F401
from .registry import DATASETS, FAMILIES, data_root, get_spec  # noqa: F401
from .combine import run, load_dataset, pick_samples, write_training_kit, CombineResult  # noqa: F401
from .stats import dataset_stats, render_report              # noqa: F401
