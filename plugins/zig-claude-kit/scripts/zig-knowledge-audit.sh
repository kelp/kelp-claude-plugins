#!/usr/bin/env bash
# zig-knowledge-audit.sh - Validate Zig breaking change claims
#
# This script tests the claims in docs/<version>/ZIG_BREAKING_CHANGES.md
# by compiling small Zig code snippets ("probes"). Each probe
# checks whether a specific old API pattern still compiles, or
# whether a specific new pattern works.
#
# Usage:
#   ./scripts/zig-knowledge-audit.sh [--version 0.15|0.16]
#   ZIG=/path/to/zig ./scripts/zig-knowledge-audit.sh --version 0.16
#
# The Zig binary used is taken from $ZIG if set, otherwise from
# `zig` on PATH. --version selects which probe set to run; defaults
# to 0.15 (preserves the original behavior). The selected version
# also dictates which docs file the probes correspond to.
#
# Interpreting results:
#   PASS - The probe result matched expectations. If the expected
#          result was "fail", the old API really is broken. If
#          "pass", the new API really works.
#   FAIL - Surprise! The result did not match expectations. This
#          means docs/<version>/ZIG_BREAKING_CHANGES.md has a wrong
#          claim and needs updating.
#
# Exit code:
#   0 - All probes matched expectations
#   1 - One or more surprises found (docs need updating)

set -euo pipefail

ZIG="${ZIG:-zig}"
VERSION="0.15"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --version=*)
            VERSION="${1#--version=}"
            shift
            ;;
        -h|--help)
            sed -n '2,29p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 2
            ;;
    esac
done

case "$VERSION" in
    0.15|0.16) ;;
    *)
        echo "Unknown --version: $VERSION (expected 0.15 or 0.16)" >&2
        exit 2
        ;;
esac

# Color support (respect NO_COLOR convention)
if [[ -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    GREEN=''
    RED=''
    BOLD=''
    DIM=''
    RESET=''
fi

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

AUDIT_TMPDIR=$(mktemp -d)
trap 'rm -rf "$AUDIT_TMPDIR"' EXIT

# probe NAME DESCRIPTION EXPECTED APPLIES_TO CODE
#   applies_to: "0.15", "0.16", or "both"
#   expected:   "pass" or "fail"
probe() {
    local name="$1"
    local description="$2"
    local expected="$3"
    local applies_to="$4"
    local code="$5"

    if [[ "$applies_to" != "both" && "$applies_to" != "$VERSION" ]]; then
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return
    fi

    local file="$AUDIT_TMPDIR/${name}.zig"
    echo "$code" > "$file"

    if "$ZIG" test "$file" --color off 2>/dev/null 1>/dev/null; then
        actual="pass"
    else
        actual="fail"
    fi

    if [[ "$actual" == "$expected" ]]; then
        printf "  ${GREEN}PASS${RESET}  %-40s %s\n" \
            "$name" "$description"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "  ${RED}FAIL${RESET}  %-40s %s ${DIM}(expected %s, got %s)${RESET}\n" \
            "$name" "$description" "$expected" "$actual"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Header
echo ""
printf "${BOLD}Zig Knowledge Audit${RESET} (version: ${BOLD}%s${RESET})\n" "$VERSION"
printf "${DIM}Testing claims against zig %s (%s)${RESET}\n" "$("$ZIG" version)" "$ZIG"

# ── I/O (Writergate) ──

printf "\n${BOLD}── I/O (Writergate) ──${RESET}\n"

probe "old_getStdOut" \
    "std.io.getStdOut() removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
}
ZIGEOF
)"

probe "old_getStdErr" \
    "std.io.getStdErr() removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const stderr = std.io.getStdErr().writer();
    _ = stderr;
}
ZIGEOF
)"

probe "old_BufferedWriter" \
    "std.io.BufferedWriter removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    _ = std.io.BufferedWriter;
}
ZIGEOF
)"

probe "new_buffered_writer_015" \
    "0.15 buffered writer pattern" \
    "pass" "0.15" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var buf: [4096]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buf);
    const stdout = &writer.interface;
    try stdout.writeAll("hello\n");
    stdout.flush() catch {};
}
ZIGEOF
)"

probe "old_fs_File_namespace" \
    "std.fs.File namespace moved to std.Io.File" \
    "fail" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { _ = std.fs.File.stdout(); }
ZIGEOF
)"

probe "new_Io_File_namespace" \
    "std.Io.File.stdout() works" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { _ = std.Io.File.stdout(); }
ZIGEOF
)"

probe "new_writerStreaming_016" \
    "0.16 buffered stdout pattern (writerStreaming with io)" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
pub fn main(init: std.process.Init) !void {
    var buf: [4096]u8 = undefined;
    var w = std.Io.File.stdout().writerStreaming(init.io, &buf);
    const stdout = &w.interface;
    defer stdout.flush() catch {};
    try stdout.writeAll("hello\n");
}
ZIGEOF
)"

probe "old_close_without_io" \
    "file.close() without io fails in 0.16" \
    "fail" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    const f = try std.Io.Dir.cwd().openFile(io, "/etc/hosts", .{});
    f.close();
}
ZIGEOF
)"

probe "new_close_with_io" \
    "file.close(io) works in 0.16" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    const f = try std.Io.Dir.cwd().openFile(io, "/etc/hosts", .{});
    f.close(io);
}
ZIGEOF
)"

# ── Collections ──

printf "\n${BOLD}── Collections ──${RESET}\n"

probe "old_arraylist_no_allocator" \
    "ArrayListUnmanaged without allocator args fails" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var list: std.ArrayListUnmanaged(u32) = .empty;
    defer list.deinit();
    list.append(42) catch {};
}
ZIGEOF
)"

probe "new_arraylist_empty_015" \
    "ArrayListUnmanaged{} literal init (0.15)" \
    "pass" "0.15" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var list = std.ArrayListUnmanaged(u32){};
    defer list.deinit(std.testing.allocator);
    try list.append(std.testing.allocator, 42);
}
ZIGEOF
)"

probe "old_arraylist_struct_literal" \
    "ArrayListUnmanaged{} literal init removed in 0.16" \
    "fail" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var list = std.ArrayListUnmanaged(u32){};
    _ = &list;
}
ZIGEOF
)"

probe "new_arraylist_empty_decl_literal" \
    ".empty decl literal initializes ArrayListUnmanaged in 0.16" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var list: std.ArrayListUnmanaged(u32) = .empty;
    defer list.deinit(std.testing.allocator);
    try list.append(std.testing.allocator, 42);
}
ZIGEOF
)"

probe "new_arraylist_alias_in_016" \
    "std.ArrayList is alias for unmanaged in 0.16" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var list: std.ArrayList(u32) = .empty;
    defer list.deinit(std.testing.allocator);
    try list.append(std.testing.allocator, 42);
}
ZIGEOF
)"

probe "old_arraylist_managed_init" \
    "ArrayList(T).init(allocator) managed API removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var list = std.ArrayList(u32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
}
ZIGEOF
)"

probe "old_BoundedArray" \
    "std.BoundedArray removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var arr = std.BoundedArray(u8, 64){};
    _ = &arr;
}
ZIGEOF
)"

probe "new_BoundedArray_replacement" \
    "ArrayListUnmanaged.initBuffer replacement" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var buffer: [64]u8 = undefined;
    var list = std.ArrayListUnmanaged(u8).initBuffer(&buffer);
    list.appendAssumeCapacity(42);
}
ZIGEOF
)"

# ── Language Features ──

printf "\n${BOLD}── Language Features ──${RESET}\n"

probe "old_usingnamespace" \
    "usingnamespace removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
const Mixin = struct { pub fn hello() void {} };
const Foo = struct { pub usingnamespace Mixin; };
test "probe" { Foo.hello(); }
ZIGEOF
)"

probe "old_async_await" \
    "async/await removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
fn asyncFn() !void {}
test "probe" { _ = async asyncFn(); }
ZIGEOF
)"

probe "old_division_signed" \
    "Runtime signed division with / fails" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
test "probe" {
    var a: i32 = 10;
    var b: i32 = 3;
    _ = &a;
    _ = &b;
    const result = a / b;
    _ = result;
}
ZIGEOF
)"

probe "new_divTrunc" \
    "@divTrunc for runtime signed division" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
test "probe" {
    var a: i32 = 10;
    var b: i32 = 3;
    _ = &a;
    _ = &b;
    const result = @divTrunc(a, b);
    _ = result;
}
ZIGEOF
)"

probe "old_at_Type_int" \
    "@Type(.{ .int = ... }) removed in 0.16" \
    "fail" "0.16" \
    "$(cat <<'ZIGEOF'
test "probe" {
    const T = @Type(.{ .int = .{ .signedness = .unsigned, .bits = 10 } });
    _ = T;
}
ZIGEOF
)"

probe "new_at_Int_builtin" \
    "@Int(.unsigned, N) builtin works in 0.16" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
test "probe" {
    const T = @Int(.unsigned, 10);
    _ = T;
}
ZIGEOF
)"

# ── Concurrency ──

printf "\n${BOLD}── Concurrency ──${RESET}\n"

probe "old_thread_mutex" \
    "std.Thread.Mutex moved to std.Io.Mutex in 0.16" \
    "fail" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { var m: std.Thread.Mutex = .{}; _ = &m; }
ZIGEOF
)"

probe "new_io_mutex_exists" \
    "std.Io.Mutex exists in 0.16" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { _ = std.Io.Mutex; }
ZIGEOF
)"

probe "old_thread_mutex_015" \
    "std.Thread.Mutex still works in 0.15" \
    "pass" "0.15" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { var m: std.Thread.Mutex = .{}; _ = &m; }
ZIGEOF
)"

# ── String / Mem ──

printf "\n${BOLD}── String / Mem ──${RESET}\n"

probe "old_mem_tokenize" \
    "std.mem.tokenize old name removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var it = std.mem.tokenize(u8, "hello world", " ");
    _ = it.next();
}
ZIGEOF
)"

probe "new_mem_tokenizeAny" \
    "std.mem.tokenizeAny replacement" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var it = std.mem.tokenizeAny(u8, "hello world", " ");
    _ = it.next();
}
ZIGEOF
)"

probe "indexOf_deprecated_alias" \
    "std.mem.indexOf is a deprecated alias for find in 0.16 (still compiles)" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { _ = std.mem.indexOf(u8, "hello", "ll"); }
ZIGEOF
)"

probe "new_mem_find" \
    "std.mem.find replaces indexOf in 0.16" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { _ = std.mem.find(u8, "hello", "ll"); }
ZIGEOF
)"

probe "new_mem_cut" \
    "std.mem.cut family added in 0.16" \
    "pass" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" { _ = std.mem.cut(u8, "key=value", "="); }
ZIGEOF
)"

# ── Process ──

printf "\n${BOLD}── Process ──${RESET}\n"

probe "old_process_args_iter_015" \
    "std.process.args() iterator (0.15)" \
    "pass" "0.15" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var args = std.process.args();
    _ = args.next();
}
ZIGEOF
)"

probe "old_process_args_iter_016" \
    "std.process.args() removed in 0.16" \
    "fail" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var args = std.process.args();
    _ = args.next();
}
ZIGEOF
)"

probe "old_process_argsAlloc_015" \
    "std.process.argsAlloc still works in 0.15" \
    "pass" "0.15" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const args = try std.process.argsAlloc(std.testing.allocator);
    defer std.process.argsFree(std.testing.allocator, args);
    try std.testing.expect(args.len > 0);
}
ZIGEOF
)"

probe "old_process_argsAlloc_016" \
    "std.process.argsAlloc removed in 0.16" \
    "fail" "0.16" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const args = try std.process.argsAlloc(std.testing.allocator);
    _ = args;
}
ZIGEOF
)"

# ── JSON ──

printf "\n${BOLD}── JSON ──${RESET}\n"

probe "old_json_parser" \
    "std.json.Parser old API removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var parser = std.json.Parser.init(std.testing.allocator, false);
    _ = &parser;
}
ZIGEOF
)"

probe "new_json_parseFromSlice" \
    "std.json.parseFromSlice new API" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
const T = struct { x: i32 };
test "probe" {
    const input = "{\"x\": 42}";
    const parsed = try std.json.parseFromSlice(T, std.testing.allocator, input, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(i32, 42), parsed.value.x);
}
ZIGEOF
)"

# ── Format Strings ──

printf "\n${BOLD}── Format Strings ──${RESET}\n"

# 0.15-only: in 0.15 the old format-method shape with `comptime fmt`
# made `"{}"` a hard compile error. In 0.16 the same code compiles
# (no error), but `"{}"` no longer invokes a custom format method —
# you must use `"{f}"` to dispatch to it. The audit can't observe
# that semantic difference (only compile pass/fail), so this probe
# is restricted to 0.15.
probe "old_format_empty_braces" \
    "Empty {} format specifier for custom types fails (0.15)" \
    "fail" "0.15" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
const Foo = struct {
    x: i32,
    pub fn format(self: Foo, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}", .{self.x});
    }
};
test "probe" {
    const foo = Foo{ .x = 42 };
    var buf: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&buf, "{}", .{foo});
}
ZIGEOF
)"

probe "new_format_method" \
    "New format method signature with {f}" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
const Foo = struct {
    x: i32,
    pub fn format(self: Foo, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{d}", .{self.x});
    }
};
test "probe" {
    const foo = Foo{ .x = 42 };
    var buf: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&buf, "{f}", .{foo});
}
ZIGEOF
)"

# ── Testing ──

printf "\n${BOLD}── Testing ──${RESET}\n"

probe "expectEqualStrings" \
    "expectEqualStrings still exists" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    try std.testing.expectEqualStrings("hello", "hello");
}
ZIGEOF
)"

probe "expectEqualSlices" \
    "expectEqualSlices works" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    try std.testing.expectEqualSlices(u8, "hello", "hello");
}
ZIGEOF
)"

# ── New Features ──

printf "\n${BOLD}── New Features ──${RESET}\n"

probe "new_destructuring" \
    "Destructuring assignments work" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
test "probe" {
    const tuple = .{ @as(i32, 1), @as(i32, 2), @as(i32, 3) };
    const x, const y, const z = tuple;
    _ = x;
    _ = y;
    _ = z;
}
ZIGEOF
)"

probe "new_multi_for" \
    "Multi-object for loops work" \
    "pass" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 4, 5, 6 };
    var sum: i32 = 0;
    for (a, b) |x, y| {
        sum += x + y;
    }
    try std.testing.expectEqual(@as(i32, 21), sum);
}
ZIGEOF
)"

probe "old_DoublyLinkedList" \
    "Generic DoublyLinkedList(T) removed" \
    "fail" "both" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var list = std.DoublyLinkedList(u32){};
    _ = &list;
}
ZIGEOF
)"

# Summary
total=$((PASS_COUNT + FAIL_COUNT))
echo ""
printf "${BOLD}Summary${RESET}: %d probes run, " "$total"
printf "${GREEN}%d confirmed${RESET}, " "$PASS_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
    printf "${RED}%d surprises${RESET}" "$FAIL_COUNT"
else
    printf "0 surprises"
fi
if [[ $SKIP_COUNT -gt 0 ]]; then
    printf " ${DIM}(%d skipped — not applicable to %s)${RESET}" "$SKIP_COUNT" "$VERSION"
fi
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo ""
    echo "Surprises indicate docs/$VERSION/ZIG_BREAKING_CHANGES.md needs updating."
    exit 1
fi
