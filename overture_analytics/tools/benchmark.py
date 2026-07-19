"""Run dbt and persist detailed, timestamped benchmark evidence."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

import duckdb


ROOT = Path(__file__).resolve().parents[1]


def find_dbt() -> Path:
    name = "dbt.exe" if os.name == "nt" else "dbt"
    candidates = [Path(sys.executable).with_name(name), ROOT.parent / ".venv" / "Scripts" / name]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError("dbt executable was not found in the project or parent virtual environment")


def parse_bbox(value: str) -> dict[str, float]:
    try:
        values = [float(item.strip()) for item in value.split(",")]
    except ValueError as exc:
        raise argparse.ArgumentTypeError("bbox values must be numeric") from exc
    if len(values) != 4:
        raise argparse.ArgumentTypeError("bbox must be xmin,ymin,xmax,ymax")
    xmin, ymin, xmax, ymax = values
    if xmin > xmax or ymin > ymax:
        raise argparse.ArgumentTypeError("bbox minimums must not exceed maximums")
    return {"xmin": xmin, "ymin": ymin, "xmax": xmax, "ymax": ymax}


def parquet_outputs(root: Path) -> list[dict[str, object]]:
    outputs: list[dict[str, object]] = []
    con = duckdb.connect()
    try:
        for path in sorted(root.glob("*.parquet")):
            rows = con.execute(
                "select coalesce(sum(num_rows), 0) from parquet_file_metadata(?)", [str(path)]
            ).fetchone()[0]
            outputs.append({"name": path.name, "bytes": path.stat().st_size, "rows": rows})
    finally:
        con.close()
    return outputs


def node_results(run_results_path: Path) -> list[dict[str, object]]:
    if not run_results_path.exists():
        return []
    payload = json.loads(run_results_path.read_text(encoding="utf-8"))
    nodes = []
    for result in payload.get("results", []):
        timing = {
            entry.get("name", "unknown"): {
                "started_at": entry.get("started_at"),
                "completed_at": entry.get("completed_at"),
            }
            for entry in result.get("timing", [])
        }
        nodes.append(
            {
                "unique_id": result.get("unique_id"),
                "status": result.get("status"),
                "execution_seconds": result.get("execution_time"),
                "thread_id": result.get("thread_id"),
                "timing": timing,
                "adapter_response": result.get("adapter_response", {}),
                "message": result.get("message"),
                "failures": result.get("failures"),
            }
        )
    return nodes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", default="2026-06-17.0")
    parser.add_argument("--bbox", type=parse_bbox, default=parse_bbox("13.08,52.34,13.76,52.68"))
    parser.add_argument("--command", choices=("run", "build"), default="run")
    parser.add_argument("--output-root", type=Path, default=Path("benchmarks"))
    args = parser.parse_args()

    now = datetime.now(timezone.utc)
    run_id = now.strftime("%Y%m%dT%H%M%S.%fZ")
    output_root = args.output_root if args.output_root.is_absolute() else ROOT / args.output_root
    run_dir = output_root / "runs" / run_id
    target_dir = run_dir / "target"
    log_dir = run_dir / "logs"
    run_dir.mkdir(parents=True, exist_ok=False)
    target_dir.mkdir()
    log_dir.mkdir()

    dbt = find_dbt()
    variables = json.dumps({"bbox": args.bbox}, separators=(",", ":"))
    command = [
        str(dbt),
        args.command,
        "--threads", "1",
        "--vars", variables,
        "--profiles-dir", str(ROOT),
        "--target-path", str(target_dir),
        "--log-path", str(log_dir),
    ]
    environment = os.environ.copy()
    environment["OVERTURE_RELEASE"] = args.release
    environment.setdefault("DUCKDB_PATH", str(ROOT / "data" / "overture.duckdb"))
    environment.setdefault("PARQUET_OUTPUT_ROOT", str(ROOT / "data" / "models"))
    Path(environment["PARQUET_OUTPUT_ROOT"]).mkdir(parents=True, exist_ok=True)

    console_path = run_dir / "console.log"
    started = time.perf_counter()
    started_at = datetime.now(timezone.utc).isoformat()
    return_code = -1
    with console_path.open("w", encoding="utf-8") as console:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        assert process.stdout is not None
        for line in process.stdout:
            print(line, end="")
            console.write(line)
        return_code = process.wait()
    elapsed = time.perf_counter() - started

    results_path = target_dir / "run_results.json"
    outputs = parquet_outputs(Path(environment["PARQUET_OUTPUT_ROOT"]))
    nodes = node_results(results_path)
    summary = {
        "run_id": run_id,
        "started_at": started_at,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "succeeded": return_code == 0,
        "return_code": return_code,
        "elapsed_seconds": round(elapsed, 3),
        "dbt_command": args.command,
        "command": command,
        "release": args.release,
        "bbox": args.bbox,
        "environment": {
            "python": platform.python_version(),
            "platform": platform.platform(),
            "duckdb": duckdb.__version__,
            "dbt_core": importlib.metadata.version("dbt-core"),
            "dbt_duckdb": importlib.metadata.version("dbt-duckdb"),
            "threads": 1,
        },
        "database": {
            "path": environment["DUCKDB_PATH"],
            "bytes": Path(environment["DUCKDB_PATH"]).stat().st_size
            if Path(environment["DUCKDB_PATH"]).exists()
            else None,
        },
        "parquet_outputs": outputs,
        "nodes": nodes,
        "artifacts": {
            "run_directory": str(run_dir),
            "console_log": str(console_path),
            "dbt_log": str(log_dir / "dbt.log"),
            "run_results": str(results_path),
            "manifest": str(target_dir / "manifest.json"),
        },
    }
    summary_path = run_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    output_root.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(summary_path, output_root / "latest.json")

    print(f"\nDetailed benchmark: {summary_path}")
    print(f"Latest summary:     {output_root / 'latest.json'}")
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
