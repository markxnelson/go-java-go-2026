#!/usr/bin/env python3
"""Plot throughput from a sequential benchmark result directory."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter


VARIANTS = [
    ("go-stdlibRpsMedian", "Go stdlib", "#2563eb", "o"),
    ("oracle-jdk-jvmRpsMedian", "Oracle JDK JVM", "#dc2626", "s"),
    ("oracle-jdk-leyden-aotRpsMedian", "Oracle JDK Leyden AOT", "#16a34a", "^"),
]

PAYLOAD_LABELS = {
    7: "7 bytes",
    128: "128 bytes",
    2048: "2 KB",
    8192: "8 KB",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("results_dir", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("article/figures/throughput-by-payload-2x2.png"),
    )
    parser.add_argument(
        "--svg-output",
        type=Path,
        default=None,
        help="Optional SVG output path.",
    )
    parser.add_argument(
        "--chart-dir",
        type=Path,
        default=None,
        help="Optional directory for the standard article chart set.",
    )
    args = parser.parse_args()

    pivot_path = args.results_dir / "throughput-pivot-by-cell.csv"
    rows = read_rows(pivot_path)
    plot_throughput_curves(rows, args.output, args.svg_output)
    if args.chart_dir is not None:
        args.chart_dir.mkdir(parents=True, exist_ok=True)
        peak_rows = read_rows(args.results_dir / "peak-throughput-by-payload.csv")
        plot_peak_throughput(
            peak_rows,
            args.chart_dir / "go-java-2026-peak-throughput.png",
        )
        plot_throughput_curves(
            rows,
            args.chart_dir / "go-java-2026-throughput-by-payload.png",
            None,
        )
        plot_tail_latency(
            peak_rows,
            args.chart_dir / "go-java-2026-tail-latency-at-peak.png",
        )
    return 0


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise SystemExit(f"missing pivot file: {path}")
    with path.open(newline="") as file:
        return list(csv.DictReader(file))


def plot_throughput_curves(
    rows: list[dict[str, str]],
    output: Path,
    svg_output: Path | None,
) -> None:
    payloads = sorted({int(row["payloadSize"]) for row in rows})
    if len(payloads) != 4:
        raise SystemExit(f"expected 4 payload sizes, found {len(payloads)}")

    fig, axes = plt.subplots(2, 2, figsize=(13, 8), sharex=True)
    fig.suptitle(
        "Median Throughput by Payload and Concurrency (Higher Is Better)",
        fontsize=17,
        fontweight="bold",
    )

    for ax, payload in zip(axes.flat, payloads):
        payload_rows = sorted(
            (row for row in rows if int(row["payloadSize"]) == payload),
            key=lambda row: int(row["concurrency"]),
        )
        concurrencies = [int(row["concurrency"]) for row in payload_rows]

        for column, label, color, marker in VARIANTS:
            values = [float(row[column]) for row in payload_rows]
            ax.plot(
                concurrencies,
                values,
                label=label,
                color=color,
                marker=marker,
                linewidth=2.2,
                markersize=5.5,
            )

        ax.set_title(PAYLOAD_LABELS.get(payload, f"{payload} bytes"), fontweight="bold")
        ax.set_xscale("log", base=2)
        ax.set_xticks(concurrencies)
        ax.set_xticklabels([str(value) for value in concurrencies])
        ax.yaxis.set_major_formatter(FuncFormatter(format_rps))
        ax.grid(True, axis="y", color="#d4d4d8", linewidth=0.8)
        ax.grid(True, axis="x", color="#e4e4e7", linewidth=0.5, alpha=0.7)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    for ax in axes[:, 0]:
        ax.set_ylabel("Requests / second")
    for ax in axes[-1, :]:
        ax.set_xlabel("Concurrency")

    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(
        handles,
        labels,
        loc="lower center",
        ncol=3,
        frameon=False,
        bbox_to_anchor=(0.5, -0.01),
    )
    fig.text(
        0.5,
        0.035,
        f"Source: throughput-pivot-by-cell.csv from {rows[0]['runId']}",
        ha="center",
        fontsize=9,
        color="#52525b",
    )
    fig.tight_layout(rect=(0, 0.08, 1, 0.94))

    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=220, bbox_inches="tight", facecolor="white")
    if svg_output is not None:
        svg_output.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(svg_output, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def plot_peak_throughput(rows: list[dict[str, str]], output: Path) -> None:
    payloads = sorted({int(row["payloadSize"]) for row in rows})
    variants = [
        ("go-stdlib", "Go stdlib", "#2563eb"),
        ("oracle-jdk-jvm", "Oracle JDK JVM", "#dc2626"),
        ("oracle-jdk-leyden-aot", "Oracle JDK Leyden AOT", "#16a34a"),
    ]
    width = 0.24
    x_positions = list(range(len(payloads)))

    fig, ax = plt.subplots(figsize=(12, 6.5))
    for index, (variant, label, color) in enumerate(variants):
        values = [
            float(match_row(rows, variant, payload)["peakRequestsPerSecondMedian"])
            for payload in payloads
        ]
        offset = (index - 1) * width
        ax.bar(
            [x + offset for x in x_positions],
            values,
            width=width,
            label=label,
            color=color,
        )

    ax.set_title(
        "Peak Median Throughput by Payload (Higher Is Better)",
        fontsize=16,
        fontweight="bold",
    )
    ax.set_xlabel("Generated payload size")
    ax.set_ylabel("Requests / second")
    ax.set_xticks(x_positions)
    ax.set_xticklabels([PAYLOAD_LABELS.get(payload, str(payload)) for payload in payloads])
    ax.yaxis.set_major_formatter(FuncFormatter(format_rps))
    ax.grid(True, axis="y", color="#d4d4d8", linewidth=0.8)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.legend(frameon=False, ncol=3, loc="upper center", bbox_to_anchor=(0.5, -0.12))
    fig.tight_layout()
    fig.savefig(output, dpi=220, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def plot_tail_latency(rows: list[dict[str, str]], output: Path) -> None:
    payloads = sorted({int(row["payloadSize"]) for row in rows})
    variants = [
        ("go-stdlib", "Go stdlib", "#2563eb", "o"),
        ("oracle-jdk-jvm", "Oracle JDK JVM", "#dc2626", "s"),
        ("oracle-jdk-leyden-aot", "Oracle JDK Leyden AOT", "#16a34a", "^"),
    ]
    fig, axes = plt.subplots(1, 2, figsize=(13, 5.6), sharex=True)

    for ax, column, title in [
        (axes[0], "p95NanosMedianAtPeak", "p95 at Peak Throughput (Lower Is Better)"),
        (axes[1], "p99NanosMedianAtPeak", "p99 at Peak Throughput (Lower Is Better)"),
    ]:
        for variant, label, color, marker in variants:
            values = [
                float(match_row(rows, variant, payload)[column]) / 1_000_000
                for payload in payloads
            ]
            ax.plot(
                payloads,
                values,
                label=label,
                color=color,
                marker=marker,
                linewidth=2.2,
                markersize=5.5,
            )
        ax.set_title(title, fontweight="bold")
        ax.set_xscale("log", base=2)
        ax.set_xticks(payloads)
        ax.set_xticklabels([PAYLOAD_LABELS.get(payload, str(payload)) for payload in payloads])
        ax.set_xlabel("Generated payload size")
        ax.set_ylabel("Milliseconds")
        ax.grid(True, axis="y", color="#d4d4d8", linewidth=0.8)
        ax.grid(True, axis="x", color="#e4e4e7", linewidth=0.5, alpha=0.7)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    fig.suptitle("Tail Latency at Peak Throughput (Lower Is Better)", fontsize=16, fontweight="bold")
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", ncol=3, frameon=False)
    fig.tight_layout(rect=(0, 0.08, 1, 0.95))
    fig.savefig(output, dpi=220, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def match_row(rows: list[dict[str, str]], variant: str, payload: int) -> dict[str, str]:
    for row in rows:
        if row["runtimeVariant"] == variant and int(row["payloadSize"]) == payload:
            return row
    raise KeyError(f"missing row for {variant} payload {payload}")


def format_rps(value: float, _position: int) -> str:
    if value >= 1000:
        return f"{value / 1000:.0f}k"
    return f"{value:.0f}"


if __name__ == "__main__":
    raise SystemExit(main())
