#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["anthropic"]
# ///
"""
Evaluate Claude models' Zig 0.15.x knowledge.

Sends prompts to the Claude API with no project context, extracts
generated Zig code, and compile-tests it to measure how many
patterns each model gets right vs. wrong.

Usage:
    uv run scripts/zig-knowledge-eval.py
    uv run scripts/zig-knowledge-eval.py --models claude-sonnet-4-6
    uv run scripts/zig-knowledge-eval.py --skip-compile
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

import anthropic

PROMPTS = [
    (
        "01_stdout",
        'Write a Zig program that prints "hello world" to stdout.'
        " Just the code, no explanation. Use the standard library.",
    ),
    (
        "02_stderr",
        "Write a Zig function that prints an error message to"
        " stderr. Just the code, no explanation.",
    ),
    (
        "03_arraylist",
        "Write a Zig test that creates an ArrayList of u32, appends"
        " three values, and checks the length is 3. Just the code.",
    ),
    (
        "04_bounded_array",
        "Write a Zig function that uses a stack-allocated bounded"
        " array (max 64 elements) of u8. Append a few values and"
        " return the slice. Just the code.",
    ),
    (
        "05_tokenize",
        "Write a Zig function that splits a string by whitespace"
        " and returns the token count. Just the code.",
    ),
    (
        "06_testing",
        "Write a Zig test that compares two strings for equality"
        " using the standard testing library. Just the code.",
    ),
    (
        "07_process_args",
        "Write a Zig program that prints each command-line argument"
        " on its own line. Just the code.",
    ),
    (
        "08_json",
        "Write a Zig test that parses the JSON string"
        ' \'{"name":"alice","age":30}\' into a struct and checks'
        " the values. Just the code.",
    ),
    (
        "09_format",
        "Write a Zig struct with an x:i32 field that implements"
        " the format method so it can be printed with std.fmt."
        " Include a test that formats it to a buffer."
        " Just the code.",
    ),
    (
        "10_mixin",
        "Write a Zig mixin pattern where a struct gains methods"
        " from another type. Just the code.",
    ),
    (
        "11_division",
        "Write a Zig function that takes two i32 parameters and"
        " returns their integer quotient. Just the code.",
    ),
    (
        "12_for_index",
        "Write a Zig function that iterates over a slice and prints"
        " each element with its index. Just the code.",
    ),
    (
        "13_build_zig",
        'Write a Zig build.zig file that builds an executable called'
        ' "hello" from src/main.zig. Just the code.',
    ),
    (
        "14_async",
        "Write a Zig program that runs two tasks concurrently using"
        " async/await. Just the code.",
    ),
]

DEFAULT_MODELS = ["claude-sonnet-4-6", "claude-opus-4-6"]


def extract_zig_code(text: str) -> str | None:
    """Extract Zig code from a Claude response."""
    # Try ```zig blocks first
    blocks = re.findall(r"```zig\n(.*?)```", text, re.DOTALL)
    if blocks:
        return "\n\n".join(b.strip() for b in blocks)

    # Try generic code blocks
    blocks = re.findall(r"```\n(.*?)```", text, re.DOTALL)
    if blocks:
        return "\n\n".join(b.strip() for b in blocks)

    # If response looks like raw code
    stripped = text.strip()
    if stripped.startswith(
        ("const ", "pub ", "fn ", "test ", "//", "var ", "const\n")
    ):
        return stripped

    return None


def query_model(
    client: anthropic.Anthropic, model: str, prompt: str
) -> str:
    """Send a prompt and return the text response."""
    response = client.messages.create(
        model=model,
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.content[0].text


def main():
    parser = argparse.ArgumentParser(
        description="Evaluate Claude models' Zig 0.15.x knowledge",
    )
    parser.add_argument(
        "--models",
        nargs="+",
        default=DEFAULT_MODELS,
        help="Models to evaluate (default: %(default)s)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("probes"),
        help="Output directory (default: probes/)",
    )
    parser.add_argument(
        "--skip-compile",
        action="store_true",
        help="Skip compilation testing",
    )
    args = parser.parse_args()

    client = anthropic.Anthropic()
    script_dir = Path(__file__).parent
    test_script = script_dir / "zig-knowledge-test.sh"

    for model in args.models:
        model_dir = args.output_dir / model
        model_dir.mkdir(parents=True, exist_ok=True)

        print(f"\n{'=' * 60}")
        print(f"  Model: {model}")
        print(f"{'=' * 60}")

        generated = 0
        skipped = 0

        for name, prompt in PROMPTS:
            print(f"  {name:30s}", end="", flush=True)

            try:
                text = query_model(client, model, prompt)
                code = extract_zig_code(text)

                if code:
                    out = model_dir / f"{name}.zig"
                    out.write_text(code + "\n")
                    generated += 1
                    print("ok")
                else:
                    # Save raw response for manual inspection
                    raw = model_dir / f"{name}.raw.txt"
                    raw.write_text(text)
                    skipped += 1
                    print("no code (saved .raw.txt)")

            except anthropic.APIError as e:
                skipped += 1
                print(f"API error: {e}")

        print(f"\n  Generated: {generated}, Skipped: {skipped}")

        if not args.skip_compile and test_script.exists():
            print(f"\n--- Compile testing: {model} ---")
            subprocess.run(
                [str(test_script), str(model_dir)],
                check=False,
            )

    print()


if __name__ == "__main__":
    main()
