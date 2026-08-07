#!/usr/bin/env python3
"""Estimate token, Codex-credit, and API-dollar usage in Pi sessions.

The script deliberately downloads pricing at runtime rather than embedding a
price table.  The two sources are OpenAI's API pricing page and its Codex
pricing/rate-card page.  Codex credits are a usage-limit unit, not a promise
that an API account is billed in credits; the dollar column is an estimate of
what the same token usage would cost through the OpenAI API.

Pi stores sessions as JSONL.  Assistant messages contain the authoritative
usage counters, so no tokenizer (and no approximation from character counts)
is needed for sessions that have usage metadata.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from urllib.request import Request, urlopen

API_PRICING_URL = "https://platform.openai.com/docs/pricing"
CODEX_PRICING_URL = "https://developers.openai.com/codex/pricing/"


@dataclass(frozen=True)
class Rate:
    # Prices are USD per one million tokens.
    input_usd: float
    cached_input_usd: float | None
    output_usd: float
    # Codex credits per one million tokens.
    input_credits: float | None = None
    cached_input_credits: float | None = None
    output_credits: float | None = None


@dataclass
class Usage:
    input: int = 0
    output: int = 0
    cached: int = 0
    cache_write: int = 0
    credits: float = 0.0
    dollars: float = 0.0
    models: set[str] | None = None
    unpriced: set[str] | None = None
    dollars_known: bool = True
    credits_known: bool = True

    def __post_init__(self) -> None:
        self.models = set() if self.models is None else self.models
        self.unpriced = set() if self.unpriced is None else self.unpriced

    @property
    def tokens(self) -> int:
        return self.input + self.output + self.cached + self.cache_write

    def add(self, other: "Usage") -> None:
        self.input += other.input
        self.output += other.output
        self.cached += other.cached
        self.cache_write += other.cache_write
        self.credits += other.credits
        self.dollars += other.dollars
        self.models.update(other.models)
        self.unpriced.update(other.unpriced)
        self.dollars_known = self.dollars_known and other.dollars_known
        self.credits_known = self.credits_known and other.credits_known


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": "pi-openai-usage/1.0"})
    with urlopen(request, timeout=20) as response:
        return response.read().decode("utf-8", errors="replace")


def number(value: str) -> float | None:
    value = value.strip().lower()
    if value in {"-", "null", "none", ""}:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def model_aliases(model: str) -> Iterable[str]:
    """Yield likely names used by OpenAI's pricing tables."""
    model = model.lower().strip()
    if "/" in model:
        model = model.rsplit("/", 1)[-1]
    seen: set[str] = set()
    candidates = [model]
    # Date-pinned model names normally have the same price as their alias.
    candidates.append(re.sub(r"-\d{4}-\d{2}-\d{2}$", "", model))
    candidates.append(re.sub(r"-latest$", "", model))
    for candidate in candidates:
        if candidate and candidate not in seen:
            seen.add(candidate)
            yield candidate


def parse_api_rates(page: str) -> dict[str, Rate]:
    """Parse the first (Standard) model table in OpenAI's pricing page.

    The page renders tables from serialized data.  Unescaping first makes
    this work for both the currently deployed HTML and ordinary JSON-like
    copies of that data.  Each row is model, input, cached input, output and
    (for some tables) an additional column; the first four values are enough.
    """
    page = html.unescape(page)
    row = re.compile(
        r'\[\[0,"(?P<model>[^"]+)"\],\[0,(?P<input>[^,\]]+)\],'
        r'\[0,(?P<cached>[^,\]]+)\],\[0,(?P<output>[^,\]]+)\]'
    )
    rates: dict[str, Rate] = {}
    for match in row.finditer(page):
        name = match.group("model").lower()
        # The first occurrence is the Standard table.  Later occurrences are
        # Batch/Flex/Priority variants and must not overwrite it.
        name = re.sub(r"\s*\(<.*?\)$", "", name)
        if name in rates:
            continue
        input_usd = number(match.group("input"))
        output_usd = number(match.group("output"))
        if input_usd is None or output_usd is None:
            continue
        rates[name] = Rate(input_usd, number(match.group("cached")), output_usd)
    return rates


def parse_codex_rates(page: str) -> dict[str, tuple[float, float, float]]:
    """Parse Codex's human-readable credits-per-million-token table."""
    text = html.unescape(page)
    text = re.sub(r"<[^>]*>", " ", text)
    text = re.sub(r"\s+", " ", text)
    # Keep this intentionally model-specific only at the display-name level;
    # the API model aliases are matched below.  This also tolerates a page
    # adding explanatory text between a model name and its three values.
    names = {
        "gpt-5.6-sol": r"GPT-5\.6 Sol",
        "gpt-5.6-terra": r"GPT-5\.6 Terra",
        "gpt-5.6-luna": r"GPT-5\.6 Luna",
        "gpt-5.5": r"GPT-5\.5(?: \(<[^>]+\))?",
        "gpt-5.4": r"GPT-5\.4(?: \(<[^>]+\))?",
        "gpt-5.4-mini": r"GPT-5\.4 mini",
        "gpt-5": r"GPT-5(?:[^.\d]|$)",
        "gpt-5.1": r"GPT-5\.1(?:[^.\d]|$)",
        "gpt-5.2": r"GPT-5\.2(?:[^.\d]|$)",
    }
    result: dict[str, tuple[float, float, float]] = {}
    for model, display in names.items():
        match = re.search(
            display + r".{0,180}?([\d.]+) credits.{0,80}?([\d.]+) credits"
            r".{0,80}?([\d.]+) credits",
            text,
            re.IGNORECASE,
        )
        if match:
            result[model] = tuple(float(match.group(i)) for i in (1, 2, 3))
    return result


def load_rates(offline: bool) -> tuple[dict[str, Rate], list[str]]:
    warnings: list[str] = []
    api: dict[str, Rate] = {}
    codex: dict[str, tuple[float, float, float]] = {}
    if not offline:
        try:
            api = parse_api_rates(fetch(API_PRICING_URL))
        except Exception as exc:  # A report is still useful without pricing.
            warnings.append(f"could not fetch API pricing: {exc}")
        try:
            codex = parse_codex_rates(fetch(CODEX_PRICING_URL))
        except Exception as exc:
            warnings.append(f"could not fetch Codex credit pricing: {exc}")
    if not api:
        warnings.append("no API prices loaded; dollar estimates will be '?'")
    if not codex:
        warnings.append("no Codex credit prices loaded; credit estimates will be '?'")
    # Match Codex's current credit card where possible.  For models that are
    # not listed on the Codex page, API dollars are not silently converted to
    # credits: that conversion is not a universal OpenAI billing rule.
    for model, rate in list(api.items()):
        credit_rate = codex.get(model)
        if credit_rate:
            api[model] = Rate(rate.input_usd, rate.cached_input_usd,
                              rate.output_usd, *credit_rate)
    return api, warnings


def as_int(value: Any) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def price_usage(message: dict[str, Any], api_rates: dict[str, Rate]) -> Usage:
    raw = message.get("usage") or {}
    result = Usage(
        input=as_int(raw.get("input")),
        output=as_int(raw.get("output")),
        cached=as_int(raw.get("cacheRead", raw.get("cachedInput", 0))),
        cache_write=as_int(raw.get("cacheWrite", 0)),
    )
    model = str(message.get("model") or "unknown")
    result.models.add(model)
    rate = next((api_rates[a] for a in model_aliases(model) if a in api_rates), None)
    if rate is None:
        result.unpriced.add(model)
        result.dollars_known = False
        result.credits_known = False
        return result

    # Pi distinguishes cache reads and writes.  OpenAI's public API card
    # exposes a discounted cached-input rate, but not a cache-write rate;
    # treat newly written cache tokens as ordinary input rather than silently
    # applying the read discount.
    result.dollars = (
        (result.input + result.cache_write) * rate.input_usd
        + result.output * rate.output_usd
        + result.cached * (rate.cached_input_usd or 0.0)
    ) / 1_000_000
    if (rate.input_credits is not None and rate.output_credits is not None
            and rate.cached_input_credits is not None):
        result.credits = (
            result.input * rate.input_credits
            + result.output * rate.output_credits
            + result.cached * rate.cached_input_credits
            + result.cache_write * rate.cached_input_credits
        ) / 1_000_000
    else:
        result.unpriced.add(model + " (credits)")
        result.credits_known = False
    return result


def text_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(
            str(block.get("text", "")) for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        )
    return ""


def inspect_session(
    path: Path, api_rates: dict[str, Rate]
) -> tuple[str, dict[str, Usage], int]:
    """Return the first request and usage grouped by model for one session."""
    first_request = ""
    by_model: dict[str, Usage] = {}
    errors = 0
    try:
        with path.open(encoding="utf-8") as stream:
            for line in stream:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    errors += 1
                    continue
                message = entry.get("message")
                if not isinstance(message, dict):
                    continue
                if message.get("role") == "user" and not first_request:
                    first_request = text_content(message.get("content"))
                if message.get("role") == "assistant" and message.get("usage"):
                    model = str(message.get("model") or "unknown")
                    by_model.setdefault(model, Usage()).add(
                        price_usage(message, api_rates)
                    )
    except (OSError, UnicodeError):
        errors += 1
    return first_request, by_model, errors


def parse_age(value: str) -> float:
    value = value.lower()
    if value == "0":
        return 0.0
    parts = re.findall(r"(\d+(?:\.\d+)?)([smhdw])", value)
    if not parts or "".join(n + u for n, u in parts) != value:
        raise ValueError("age must look like 30m, 24h, 7d, 1w, or 1w2d")
    factors = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}
    return sum(float(n) * factors[u] for n, u in parts)


def choose_directory(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    old = Path.home() / ".pi" / "sessions"
    current = Path.home() / ".pi" / "agent" / "sessions"
    return old if old.is_dir() else current


def shorten(value: str, width: int) -> str:
    value = re.sub(r"\s+", " ", value).strip()
    if len(value) <= width:
        return value
    return value[: max(0, width - 1)] + "…"


def fmt_tokens(usage: Usage) -> str:
    return f"{usage.tokens:,} ({usage.input:,}/{usage.cached:,}/{usage.output:,})"


def fmt_usage(usage: Usage) -> list[str]:
    return [
        fmt_tokens(usage),
        f"{usage.credits:,.2f}" if usage.credits_known else "?",
        f"${usage.dollars:.4f}" if usage.dollars_known else "?",
    ]


def print_table(
    headers: tuple[str, ...],
    values: list[list[str]],
    row_styles: list[str | None] | None = None,
) -> None:
    widths = [max(len(headers[i]), *(len(row[i]) for row in values)) for i in range(len(headers))]
    print("  ".join(headers[i].ljust(widths[i]) for i in range(len(headers))))
    print("  ".join("-" * width for width in widths))
    for index, row in enumerate(values):
        line = "  ".join(row[i].ljust(widths[i]) for i in range(len(headers)))
        style = row_styles[index] if row_styles and index < len(row_styles) else None
        if style:
            line = f"\033[{style}m{line}\033[0m"
        print(line)


def report(
    rows: list[tuple[Path, str, dict[str, Usage]]],
    total: Usage,
    model_total: dict[str, Usage],
) -> None:
    # A session can contain several models.  Keep one row per session/model
    # here, rather than collapsing a session to its first or last model.
    headers = (
        "SESSION", "MODEL", "FIRST REQUEST", "TOKENS (in/cache/out)",
        "CREDITS", "API USD",
    )
    values: list[list[str]] = []
    row_styles: list[str | None] = []
    session_style = 0
    for path, first, models in rows:
        style = "7" if session_style % 2 else None  # inverse video / default
        if models:
            for model, usage in sorted(models.items()):
                values.append([
                    path.name, model, shorten(first, 48) or "-", *fmt_usage(usage)
                ])
                row_styles.append(style)
        else:
            values.append([path.name, "-", shorten(first, 48) or "-", *fmt_usage(Usage())])
            row_styles.append(style)
        session_style += 1
    values.append(["TOTAL", "", "", *fmt_usage(total)])
    row_styles.append(None)
    print_table(headers, values, row_styles)

    print("\nBy model across all sessions:")
    model_headers = ("MODEL", "TOKENS (in/cache/out)", "CREDITS", "API USD")
    model_values = [
        [model, *fmt_usage(usage)]
        for model, usage in sorted(model_total.items())
    ]
    model_values.append(["TOTAL", *fmt_usage(total)])
    print_table(model_headers, model_values)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("age", nargs="?", default="1w", help="maximum session-file age (default: 1w; e.g. 24h, 7d, 1w2d)")
    parser.add_argument("--sessions-dir", help="session directory (default: ~/.pi/agent/sessions, or ~/.pi/sessions)")
    parser.add_argument("--offline", action="store_true", help="do not download prices; report tokens only")
    args = parser.parse_args(argv)
    try:
        age = parse_age(args.age)
    except ValueError as exc:
        parser.error(str(exc))
    directory = choose_directory(args.sessions_dir)
    if not directory.is_dir():
        print(f"session directory does not exist: {directory}", file=sys.stderr)
        return 2
    api_rates, warnings = load_rates(args.offline)
    cutoff = time.time() - age
    paths = sorted((p for p in directory.rglob("*.jsonl") if p.is_file() and p.stat().st_mtime >= cutoff), key=lambda p: p.stat().st_mtime)
    rows: list[tuple[Path, str, dict[str, Usage]]] = []
    total = Usage()
    model_total: dict[str, Usage] = {}
    bad = 0
    for path in paths:
        first, models, errors = inspect_session(path, api_rates)
        rows.append((path, first, models))
        for model, usage in models.items():
            model_total.setdefault(model, Usage()).add(usage)
            total.add(usage)
        bad += errors
    print(f"Sessions newer than {args.age}: {len(rows)}  ({directory})")
    print(f"Prices: {API_PRICING_URL} and {CODEX_PRICING_URL}")
    report(rows, total, model_total)
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)
    if bad:
        print(f"warning: skipped {bad} malformed/unreadable JSONL lines", file=sys.stderr)
    unknown = sorted(total.unpriced)
    if unknown:
        print("warning: no current price was found for: " + ", ".join(unknown), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
