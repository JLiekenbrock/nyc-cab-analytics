"""Report source volume and benchmark a clean dbt build.

The source byte total is the compressed size of the configured Parquet objects,
not a claim that DuckDB transferred every byte. DuckDB can skip columns and row
groups through Parquet projection and predicate pushdown.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen

import duckdb


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data" / "nyc_cabs.duckdb"


def human_bytes(value: int | None) -> str:
    if value is None:
        return "unknown"
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024 or unit == "TiB":
            return f"{size:.1f} {unit}"
        size /= 1024
    raise AssertionError("unreachable")


def configured_sources() -> list[str]:
    override = os.getenv("TLC_TRIP_DATA_FILES")
    if override:
        value = ast.literal_eval(override)
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            raise ValueError("TLC_TRIP_DATA_FILES must be a Python-style list of strings")
        return value

    text = (ROOT / "models" / "sources.yml").read_text(encoding="utf-8")
    match = re.search(r'env_var\(\'TLC_TRIP_DATA_FILES\',\s*"(\[.*?\])"\)', text, re.DOTALL)
    if not match:
        raise RuntimeError("Could not find the default TLC_TRIP_DATA_FILES list")
    return ast.literal_eval(match.group(1))


def remote_size(url: str) -> int | None:
    if not url.startswith(("http://", "https://")):
        return None
    request = Request(url, method="HEAD", headers={"User-Agent": "nyc-cab-benchmark/1.0"})
    with urlopen(request, timeout=30) as response:
        length = response.headers.get("Content-Length")
    return int(length) if length else None


def database_stats(path: Path) -> dict[str, object]:
    if not path.exists():
        return {"path": str(path), "exists": False}
    con = duckdb.connect(str(path), read_only=True)
    try:
        relations = []
        query = """
            select schema_name, table_name
            from duckdb_tables()
            where not internal
            order by schema_name, table_name
        """
        for schema, table in con.execute(query).fetchall():
            quoted_schema = schema.replace('"', '""')
            quoted_table = table.replace('"', '""')
            rows = con.execute(
                f'select count(*) from "{quoted_schema}"."{quoted_table}"'
            ).fetchone()[0]
            relations.append({"relation": f"{schema}.{table}", "rows": rows})
        size = con.execute("pragma database_size").fetchone()
        return {
            "path": str(path),
            "exists": True,
            "file_bytes": path.stat().st_size,
            "database_size": size[1],
            "relations": relations,
        }
    finally:
        con.close()


def parquet_stats(root: Path) -> dict[str, object]:
    files = sorted(root.rglob("*.parquet")) if root.exists() else []
    return {
        "root": str(root),
        "file_count": len(files),
        "total_bytes": sum(path.stat().st_size for path in files),
        "files": [
            {"name": str(path.relative_to(root)), "bytes": path.stat().st_size}
            for path in files
        ],
    }


def run_build(sources: list[str]) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix="nyc-cab-benchmark-") as temp:
        temp_path = Path(temp)
        db_path = temp_path / "benchmark.duckdb"
        parquet_root = temp_path / "models"
        parquet_root.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env.update(
            {
                "DUCKDB_PATH": str(db_path),
                "DAILY_SUMMARY_EXPORT_PATH": str(temp_path / "daily.parquet"),
                "MONTHLY_PERFORMANCE_EXPORT_PATH": str(temp_path / "monthly.parquet"),
                "TLC_TRIP_DATA_FILES": repr(sources),
                "PARQUET_OUTPUT_ROOT": str(parquet_root),
            }
        )
        dbt = Path(sys.executable).with_name("dbt.exe" if os.name == "nt" else "dbt")
        # Benchmark model processing rather than `dbt build`: source tests would
        # scan the remote Parquet files before the models and can trigger the
        # public TLC CDN's range-request rate limit. Tests can be timed separately
        # after data has been materialized when required.
        command = [str(dbt), "run", "--threads", "1", "--profiles-dir", str(ROOT)]
        started = time.perf_counter()
        result = subprocess.run(command, cwd=ROOT, env=env)
        elapsed = time.perf_counter() - started
        return {
            "elapsed_seconds": round(elapsed, 3),
            "succeeded": result.returncode == 0,
            "return_code": result.returncode,
            "database": database_stats(db_path),
            "parquet_outputs": parquet_stats(parquet_root),
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="run a clean build in a temporary directory")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("benchmarks/latest.json"),
        help="write the concise JSON summary here (default: benchmarks/latest.json)",
    )
    parser.add_argument(
        "--source-metadata",
        action="store_true",
        help="probe HTTP source object sizes (some CDNs reject these requests)",
    )
    parser.add_argument(
        "--years",
        nargs="+",
        type=int,
        metavar="YEAR",
        help="process only source filenames matching these years",
    )
    args = parser.parse_args()

    configured = configured_sources()
    if args.years:
        years = set(args.years)
        configured = [
            source
            for source in configured
            if (match := re.search(r"yellow_tripdata_(\d{4})-\d{2}\.parquet$", source))
            and int(match.group(1)) in years
        ]
        if not configured:
            parser.error(f"no configured sources matched years: {sorted(years)}")

    sources = []
    for source in configured:
        size, error = None, None
        if args.source_metadata:
            try:
                size = remote_size(source)
            except Exception as exc:  # A report should survive unavailable remote metadata.
                error = str(exc)
        sources.append({"location": source, "compressed_bytes": size, "error": error})

    report: dict[str, object] = {
        "source_files": sources,
        "known_source_bytes": sum(item["compressed_bytes"] or 0 for item in sources),
        "source_sizes_known": sum(item["compressed_bytes"] is not None for item in sources),
        "existing_database": database_stats(DEFAULT_DB),
        "note": (
            "Source bytes are compressed object sizes; actual bytes read may be lower due to Parquet pushdown."
            if args.source_metadata
            else "Remote source-size probing was skipped; use --source-metadata to enable it."
        ),
    }
    if args.run:
        report["clean_build"] = run_build([item["location"] for item in sources])

    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_file_count": len(sources),
        "years": sorted(args.years) if args.years else None,
        "source_sizes_known": report["source_sizes_known"],
        "known_source_bytes": (
            report["known_source_bytes"] if report["source_sizes_known"] else None
        ),
        "existing_database": report["existing_database"],
        "note": report["note"],
    }
    if "clean_build" in report:
        summary["clean_build"] = report["clean_build"]
    output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        coverage = f"{report['source_sizes_known']}/{len(sources)} file sizes known"
        if args.source_metadata:
            print(f"Configured source volume: {human_bytes(report['known_source_bytes'])} ({coverage})")
            for item in sources:
                suffix = item["error"] or human_bytes(item["compressed_bytes"])
                print(f"  {suffix:>12}  {item['location']}")
        else:
            print(f"Configured sources:      {len(sources)} files (size probing skipped)")
        existing = report["existing_database"]
        if existing["exists"]:
            print(f"Existing DuckDB file:   {human_bytes(existing['file_bytes'])} ({existing['database_size']})")
            for relation in existing["relations"]:
                print(f"  {relation['rows']:>12,} rows  {relation['relation']}")
        if "clean_build" in report:
            build = report["clean_build"]
            status = "succeeded" if build["succeeded"] else f"failed (exit {build['return_code']})"
            print(f"Clean build elapsed:    {build['elapsed_seconds']:.3f} seconds, {status}")
            if build["database"]["exists"]:
                print(f"Clean build DB size:    {human_bytes(build['database']['file_bytes'])}")
        print(f"Note: {report['note']}")
        print(f"Saved JSON report:      {output}")
    return 0 if not args.run or report["clean_build"]["succeeded"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
