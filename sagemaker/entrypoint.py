"""Run the upstream pretraining scripts without modifying their source code."""

from __future__ import annotations

import os
import runpy
import shutil
import tempfile
from pathlib import Path


CODE_ROOT = Path(__file__).resolve().parents[1]
UPSTREAM_ROOT = CODE_ROOT / "third_party" / "deep-learning-from-scratch-6"

JOB_CONFIG = {
    "ch03": {
        "script": "ch03/01_pretrain.py",
        "package": "codebot",
        "inputs": {
            "DLFS_TRAIN_DATA_PATH": "codebot/tiny_codes.bin",
            "DLFS_TOKENIZER_PATH": "codebot/merge_rules.pkl",
        },
        "outputs": {
            "DLFS_MODEL_PATH": "codebot/model_pretrain.pt",
            "DLFS_LOSS_PLOT_PATH": "loss_pretrain.png",
        },
    },
    "ch06": {
        "script": "ch06/05_pretrain.py",
        "package": "storybot",
        "inputs": {
            "DLFS_TRAIN_DATA_PATH": "storybot/tiny_stories_train.bin",
            "DLFS_VALID_DATA_PATH": "storybot/tiny_stories_valid.bin",
            "DLFS_TOKENIZER_PATH": "storybot/merge_rules.pkl",
        },
        "outputs": {
            "DLFS_MODEL_PATH": "storybot/model_pretrain.pt",
            "DLFS_LOSS_PLOT_PATH": "loss_val.png",
        },
    },
}


def absolute_path(value: str) -> Path:
    return Path(os.path.abspath(value))


def create_link(link_path: Path, target_path: Path) -> None:
    link_path.parent.mkdir(parents=True, exist_ok=True)
    link_path.symlink_to(target_path)


def prepare_runtime(runtime_root: Path, config: dict[str, object]) -> Path:
    script_relative_path = Path(str(config["script"]))
    create_link(
        runtime_root / script_relative_path,
        UPSTREAM_ROOT / script_relative_path,
    )

    package_name = str(config["package"])
    package_source = UPSTREAM_ROOT / package_name
    package_runtime = runtime_root / package_name
    package_runtime.mkdir(parents=True, exist_ok=True)
    for source_path in package_source.glob("*.py"):
        create_link(package_runtime / source_path.name, source_path)

    for environment_name, relative_path in config["inputs"].items():
        create_link(
            runtime_root / str(relative_path),
            absolute_path(os.environ[str(environment_name)]),
        )

    return runtime_root / script_relative_path


def collect_outputs(runtime_root: Path, config: dict[str, object]) -> None:
    for environment_name, relative_path in config["outputs"].items():
        source_path = runtime_root / str(relative_path)
        if source_path.exists():
            output_path = absolute_path(os.environ[str(environment_name)])
            output_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(source_path, output_path)

    package_name = str(config["package"])
    checkpoint_dir = absolute_path(os.environ["DLFS_CHECKPOINT_DIR"])
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    for checkpoint_path in (runtime_root / package_name).glob("model_iter_*.pt"):
        shutil.move(checkpoint_path, checkpoint_dir / checkpoint_path.name)


def main() -> None:
    target = os.environ["DLFS_TARGET"]
    try:
        config = JOB_CONFIG[target]
    except KeyError as error:
        raise ValueError(f"Unknown DLFS_TARGET: {target!r}") from error

    original_directory = Path.cwd()
    with tempfile.TemporaryDirectory(prefix=f"dlfs6-{target}-") as temporary_directory:
        runtime_root = Path(temporary_directory)
        script_path = prepare_runtime(runtime_root, config)
        print(f"Running upstream script: {config['script']}", flush=True)
        try:
            runpy.run_path(str(script_path), run_name="__main__")
        finally:
            os.chdir(original_directory)
            collect_outputs(runtime_root, config)


if __name__ == "__main__":
    main()
