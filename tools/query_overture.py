"""Query a configurable Overture Maps GeoParquet slice from anonymous S3."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import time

import duckdb


DEFAULT_RELEASE = "2026-06-17.0"
IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$")


def columns(value: str) -> str:
    items = [item.strip() for item in value.split(",")]
    if not items or any(item != "*" and not IDENTIFIER.fullmatch(item) for item in items):
        raise argparse.ArgumentTypeError("columns must be comma-separated identifiers or *")
    return ", ".join(items)


def path_component(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", value):
        raise argparse.ArgumentTypeError("value contains unsupported path characters")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=path_component, default=DEFAULT_RELEASE)
    parser.add_argument("--theme", type=path_component, default="places")
    parser.add_argument("--type", dest="feature_type", type=path_component, default="place")
    parser.add_argument(
        "--bbox",
        nargs=4,
        type=float,
        metavar=("XMIN", "YMIN", "XMAX", "YMAX"),
        help="keep features whose bounding boxes intersect this WGS84 box",
    )
    parser.add_argument("--subtype", help="optional exact subtype filter")
    parser.add_argument("--class", dest="feature_class", help="optional exact class filter")
    parser.add_argument("--columns", type=columns, default="*", help="comma-separated columns")
    parser.add_argument("--limit", type=int, help="maximum rows to write")
    parser.add_argument("--output", type=Path, default=Path("data/exports/overture_extract.parquet"))
    args = parser.parse_args()

    if args.limit is not None and args.limit < 1:
        parser.error("--limit must be positive")
    if args.bbox and (args.bbox[0] > args.bbox[2] or args.bbox[1] > args.bbox[3]):
        parser.error("--bbox requires XMIN <= XMAX and YMIN <= YMAX")

    source = (
        "s3://overturemaps-us-west-2/release/"
        f"{args.release}/theme={args.theme}/type={args.feature_type}/*.parquet"
    )
    predicates: list[str] = []
    parameters: list[object] = [source]
    if args.bbox:
        xmin, ymin, xmax, ymax = args.bbox
        predicates.extend(
            ["bbox.xmax >= ?", "bbox.xmin <= ?", "bbox.ymax >= ?", "bbox.ymin <= ?"]
        )
        parameters.extend([xmin, xmax, ymin, ymax])
    if args.subtype:
        predicates.append("subtype = ?")
        parameters.append(args.subtype)
    if args.feature_class:
        predicates.append('"class" = ?')
        parameters.append(args.feature_class)

    query = f"SELECT {args.columns} FROM read_parquet(?, hive_partitioning=true)"
    if predicates:
        query += " WHERE " + " AND ".join(predicates)
    if args.limit:
        query += f" LIMIT {args.limit}"

    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output_sql = str(output).replace("'", "''")

    con = duckdb.connect()
    try:
        con.execute("LOAD httpfs")
        con.execute("SET s3_region='us-west-2'")
        con.execute("SET http_keep_alive=false")
        con.execute("SET http_retries=10")
        con.execute("SET http_timeout=120")
        started = time.perf_counter()
        con.execute(f"COPY ({query}) TO '{output_sql}' (FORMAT PARQUET, COMPRESSION ZSTD)", parameters)
        elapsed = time.perf_counter() - started
        rows = con.execute("SELECT num_rows FROM parquet_file_metadata(?)", [str(output)]).fetchone()[0]
    finally:
        con.close()

    print(f"Source:  {source}")
    print(f"Output:  {output}")
    print(f"Rows:    {rows:,}")
    print(f"Size:    {output.stat().st_size:,} bytes")
    print(f"Elapsed: {elapsed:.3f} seconds")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
