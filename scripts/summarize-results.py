#!/usr/bin/env python3
"""Create chart-friendly rollups from a sequential benchmark result directory."""

from __future__ import annotations

import argparse
import csv
import statistics
from collections import defaultdict
from pathlib import Path


GROUP_COLUMNS = [
    "runId",
    "runtimeVariant",
    "service",
    "workFactor",
    "endpointMode",
    "payloadSize",
    "concurrency",
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("results_dir", type=Path)
    args = parser.parse_args()

    results_dir = args.results_dir
    measurements_path = results_dir / "measurements.csv"
    if not measurements_path.exists():
        raise SystemExit(f"missing measurements file: {measurements_path}")

    rows = read_rows(measurements_path)
    if not rows:
        raise SystemExit(f"no measurement rows in {measurements_path}")

    summary_rows = summarize_by_cell(rows)
    write_csv(results_dir / "summary-by-cell.csv", summary_rows)
    write_csv(results_dir / "peak-throughput-by-payload.csv", peak_rows(summary_rows))
    write_csv(results_dir / "throughput-pivot-by-cell.csv", pivot_rows(summary_rows))
    write_readme(results_dir, rows, summary_rows)
    return 0


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as file:
        reader = csv.DictReader(file)
        rows = []
        for row in reader:
            if None in row:
                continue
            if any(row.get(column, "") == "" for column in GROUP_COLUMNS):
                continue
            rows.append(row)
        return rows


def summarize_by_cell(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    grouped: dict[tuple[str, ...], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[tuple(row.get(column, "") for column in GROUP_COLUMNS)].append(row)

    output = []
    for key in sorted(grouped, key=sort_key):
        group = grouped[key]
        rps = numbers(group, "requestsPerSecond")
        failures = integers(group, "failures")
        output.append(
            {
                **dict(zip(GROUP_COLUMNS, key)),
                "repeats": len(group),
                "requestsPerSecondMean": rounded(statistics.fmean(rps)),
                "requestsPerSecondMedian": rounded(statistics.median(rps)),
                "requestsPerSecondMin": rounded(min(rps)),
                "requestsPerSecondMax": rounded(max(rps)),
                "p50NanosMedian": int(statistics.median(integers(group, "p50Nanos"))),
                "p95NanosMedian": int(statistics.median(integers(group, "p95Nanos"))),
                "p99NanosMedian": int(statistics.median(integers(group, "p99Nanos"))),
                "p999NanosMedian": int(statistics.median(integers(group, "p999Nanos"))),
                "failuresTotal": sum(failures),
            }
        )
    return output


def peak_rows(summary_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[tuple[object, ...], list[dict[str, object]]] = defaultdict(list)
    for row in summary_rows:
        key = (
            row["runId"],
            row["runtimeVariant"],
            row["service"],
            row["workFactor"],
            row["endpointMode"],
            row["payloadSize"],
        )
        grouped[key].append(row)

    output = []
    for key in sorted(grouped, key=sort_key):
        best = max(grouped[key], key=lambda row: float(row["requestsPerSecondMedian"]))
        output.append(
            {
                "runId": key[0],
                "runtimeVariant": key[1],
                "service": key[2],
                "workFactor": key[3],
                "endpointMode": key[4],
                "payloadSize": key[5],
                "bestConcurrency": best["concurrency"],
                "peakRequestsPerSecondMedian": best["requestsPerSecondMedian"],
                "p95NanosMedianAtPeak": best["p95NanosMedian"],
                "p99NanosMedianAtPeak": best["p99NanosMedian"],
                "failuresTotalAtPeak": best["failuresTotal"],
            }
        )
    return output


def pivot_rows(summary_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    variants = sorted({str(row["runtimeVariant"]) for row in summary_rows})
    grouped: dict[tuple[object, ...], dict[str, object]] = {}
    for row in summary_rows:
        key = (
            row["runId"],
            row["workFactor"],
            row["endpointMode"],
            row["payloadSize"],
            row["concurrency"],
        )
        grouped.setdefault(
            key,
            {
                "runId": key[0],
                "workFactor": key[1],
                "endpointMode": key[2],
                "payloadSize": key[3],
                "concurrency": key[4],
            },
        )
        grouped[key][f"{row['runtimeVariant']}RpsMedian"] = row["requestsPerSecondMedian"]

    output = []
    for key in sorted(grouped, key=sort_key):
        row = grouped[key]
        for variant in variants:
            row.setdefault(f"{variant}RpsMedian", "")
        output.append(row)
    return output


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_readme(
    results_dir: Path,
    rows: list[dict[str, str]],
    summary_rows: list[dict[str, object]],
) -> None:
    variants = sorted({row["runtimeVariant"] for row in rows})
    services = sorted({row["service"] for row in rows})
    endpoint_modes = sorted({row.get("endpointMode", "") for row in rows})
    payloads = sorted({row["payloadSize"] for row in rows}, key=int)
    concurrencies = sorted({row["concurrency"] for row in rows}, key=int)

    text = [
        f"# Benchmark Results: {results_dir.name}",
        "",
        f"- measurements: {len(rows)} rows",
        f"- summarized cells: {len(summary_rows)} rows",
        f"- services: {', '.join(services)}",
        f"- runtime variants: {', '.join(variants)}",
        f"- endpoint modes: {', '.join(endpoint_modes)}",
        f"- payload sizes: {', '.join(payloads)}",
        f"- concurrency levels: {', '.join(concurrencies)}",
        "",
        "## Files",
        "",
        "- `measurements.csv`: every repeat from the benchmark matrix.",
        "- `configurations.csv`: runtime configuration and skip/ran status for each variant.",
        "- `summary-by-cell.csv`: repeat-level rollups by runtime, payload, and concurrency.",
        "- `peak-throughput-by-payload.csv`: best median throughput cell for each runtime and payload.",
        "- `throughput-pivot-by-cell.csv`: median throughput pivoted for charting runtime comparisons.",
        "",
    ]
    (results_dir / "README.md").write_text("\n".join(text))


def numbers(rows: list[dict[str, str]], column: str) -> list[float]:
    return [float(row[column]) for row in rows if row.get(column, "") != ""]


def integers(rows: list[dict[str, str]], column: str) -> list[int]:
    return [int(row[column]) for row in rows if row.get(column, "") != ""]


def rounded(value: float) -> str:
    return f"{value:.2f}"


def sort_key(value: object) -> tuple[object, ...]:
    if isinstance(value, tuple):
        return tuple(sort_part(part) for part in value)
    if isinstance(value, dict):
        return tuple(sort_part(value.get(column, "")) for column in GROUP_COLUMNS)
    return (value,)


def sort_part(value: object) -> object:
    text = str(value)
    return int(text) if text.isdigit() else text


if __name__ == "__main__":
    raise SystemExit(main())
