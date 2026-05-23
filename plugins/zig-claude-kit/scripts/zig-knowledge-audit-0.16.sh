#!/usr/bin/env bash
# zig-knowledge-audit-0.16.sh - Validate 0.16 breaking change claims
#
# This script tests the claims in docs/ZIG_BREAKING_CHANGES-0.16.md by
# compiling small Zig code snippets ("probes"). Each probe checks
# whether a specific old or new API pattern compiles under Zig 0.16.
#
# Usage:
#   ./scripts/zig-knowledge-audit-0.16.sh
#
# Interpreting results:
#   PASS - The probe result matched expectations. If "fail" was
#          expected, the old API really is broken in 0.16. If "pass",
#          the new API really works.
#   FAIL - Surprise! Probe didn't match. This means
#          docs/ZIG_BREAKING_CHANGES-0.16.md has a wrong claim and
#          needs updating, OR the patterns below need revision.
#
# Exit code:
#   0 - All probes matched expectations
#   1 - One or more surprises found (docs need updating)

set -euo pipefail

if [[ -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    GREEN='' RED='' BOLD='' DIM='' RESET=''
fi

PASS_COUNT=0
FAIL_COUNT=0

AUDIT_TMPDIR=$(mktemp -d)
trap 'rm -rf "$AUDIT_TMPDIR"' EXIT

probe() {
    local name="$1"
    local description="$2"
    local expected="$3"
    local code="$4"

    local file="$AUDIT_TMPDIR/${name}.zig"
    echo "$code" > "$file"

    if zig test "$file" --color off 2>/dev/null 1>/dev/null; then
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

echo ""
printf "${BOLD}Zig 0.16 Knowledge Audit${RESET}\n"
printf "${DIM}Testing 0.16 breaking change claims against zig $(zig version)${RESET}\n"

# -- I/O namespace move --

printf "\n${BOLD}-- I/O namespace move (std.io -> std.Io) --${RESET}\n"

probe "old_std_fs_File_stdout" \
    "std.fs.File.stdout() moved" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    _ = &w;
}
ZIGEOF
)"

probe "new_std_Io_File_stdout" \
    "std.Io.File.stdout() works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const f = std.Io.File.stdout();
    _ = f;
}
ZIGEOF
)"

probe "old_getStdOut" \
    "std.io.getStdOut() still removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
}
ZIGEOF
)"

# -- Filesystem move --

printf "\n${BOLD}-- Filesystem (std.fs -> std.Io) --${RESET}\n"

probe "old_std_fs_cwd" \
    "std.fs.cwd() moved" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const dir = std.fs.cwd();
    _ = dir;
}
ZIGEOF
)"

probe "new_std_Io_Dir_cwd" \
    "std.Io.Dir.cwd() works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const dir = std.Io.Dir.cwd();
    _ = dir;
}
ZIGEOF
)"

probe "old_makeDir" \
    "Dir.makeDir renamed to createDir" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const io = std.testing.io;
    try std.Io.Dir.cwd().makeDir("nope");
    _ = io;
}
ZIGEOF
)"

probe "old_File_writeAll_no_io" \
    "File.writeAll without io fails" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const f = std.Io.File.stdout();
    try f.writeAll("hi");
}
ZIGEOF
)"

# -- mem.indexOf -> find rename --

printf "\n${BOLD}-- mem.indexOf -> find rename --${RESET}\n"

probe "old_mem_indexOf" \
    "std.mem.indexOf renamed to find" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    _ = std.mem.indexOf(u8, "hello", "ll");
}
ZIGEOF
)"

probe "new_mem_find" \
    "std.mem.find replacement works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    _ = std.mem.find(u8, "hello", "ll");
}
ZIGEOF
)"

probe "new_mem_findScalar" \
    "std.mem.findScalar replacement works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    _ = std.mem.findScalar(u8, "hello", 'e');
}
ZIGEOF
)"

# -- Process state --

printf "\n${BOLD}-- Process state (args/env no longer global) --${RESET}\n"

probe "old_argsAlloc" \
    "std.process.argsAlloc removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    const args = try std.process.argsAlloc(std.testing.allocator);
    defer std.process.argsFree(std.testing.allocator, args);
}
ZIGEOF
)"

probe "old_os_environ" \
    "std.os.environ removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    _ = std.os.environ;
}
ZIGEOF
)"

probe "old_getCwd" \
    "std.process.getCwd removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var buf: [1024]u8 = undefined;
    _ = try std.process.getCwd(&buf);
}
ZIGEOF
)"

# -- Sync primitives moved --

printf "\n${BOLD}-- Sync primitives (Thread.* -> Io.*) --${RESET}\n"

probe "old_Thread_Mutex" \
    "std.Thread.Mutex moved to Io" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var m: std.Thread.Mutex = .{};
    _ = &m;
}
ZIGEOF
)"

probe "new_Io_Mutex" \
    "std.Io.Mutex works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var m: std.Io.Mutex = .{};
    _ = &m;
}
ZIGEOF
)"

probe "old_Thread_Pool" \
    "std.Thread.Pool removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var pool: std.Thread.Pool = undefined;
    _ = &pool;
}
ZIGEOF
)"

# -- Time / Crypto --

printf "\n${BOLD}-- Time / Random --${RESET}\n"

probe "old_time_Instant" \
    "std.time.Instant removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var i: std.time.Instant = undefined;
    _ = &i;
}
ZIGEOF
)"

probe "new_Io_Timestamp" \
    "std.Io.Timestamp works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var t: std.Io.Timestamp = undefined;
    _ = &t;
}
ZIGEOF
)"

# -- @Type split --

printf "\n${BOLD}-- @Type split into 8 builtins --${RESET}\n"

probe "old_Type_int" \
    "@Type(.{ .int = ...}) removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
test "probe" {
    const T = @Type(.{ .int = .{ .signedness = .unsigned, .bits = 10 } });
    _ = T;
}
ZIGEOF
)"

probe "new_Int_builtin" \
    "@Int(.unsigned, 10) works" \
    "pass" \
    "$(cat <<'ZIGEOF'
test "probe" {
    const T = @Int(.unsigned, 10);
    _ = T;
}
ZIGEOF
)"

# -- Containers --

printf "\n${BOLD}-- Containers (managed hash maps removed) --${RESET}\n"

probe "old_AutoArrayHashMap_init" \
    "AutoArrayHashMap.init removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var m = std.AutoArrayHashMap(u32, u32).init(std.testing.allocator);
    defer m.deinit();
}
ZIGEOF
)"

probe "new_array_hash_map_Auto" \
    "array_hash_map.Auto with .empty works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var m: std.array_hash_map.Auto(u32, u32) = .empty;
    defer m.deinit(std.testing.allocator);
}
ZIGEOF
)"

# -- Carry-over from 0.15 --

printf "\n${BOLD}-- Carry-over from 0.15 (still broken in 0.16) --${RESET}\n"

probe "old_usingnamespace" \
    "usingnamespace still removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
const Mixin = struct { pub fn hello() void {} };
const Foo = struct { pub usingnamespace Mixin; };
test "probe" { Foo.hello(); }
ZIGEOF
)"

probe "old_async_await" \
    "async/await still removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
fn asyncFn() !void {}
test "probe" { _ = async asyncFn(); }
ZIGEOF
)"

probe "old_BoundedArray" \
    "std.BoundedArray still removed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var arr = std.BoundedArray(u8, 64){};
    _ = &arr;
}
ZIGEOF
)"

probe "old_division_signed" \
    "Signed / on runtime ints still rejected" \
    "fail" \
    "$(cat <<'ZIGEOF'
test "probe" {
    var a: i32 = 10;
    var b: i32 = 3;
    _ = &a; _ = &b;
    const result = a / b;
    _ = result;
}
ZIGEOF
)"

probe "new_divTrunc" \
    "@divTrunc still works" \
    "pass" \
    "$(cat <<'ZIGEOF'
test "probe" {
    var a: i32 = 10;
    var b: i32 = 3;
    _ = &a; _ = &b;
    const r = @divTrunc(a, b);
    _ = r;
}
ZIGEOF
)"

probe "old_mem_tokenize" \
    "std.mem.tokenize still renamed" \
    "fail" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var it = std.mem.tokenize(u8, "hello world", " ");
    _ = it.next();
}
ZIGEOF
)"

probe "new_mem_tokenizeAny" \
    "std.mem.tokenizeAny still works" \
    "pass" \
    "$(cat <<'ZIGEOF'
const std = @import("std");
test "probe" {
    var it = std.mem.tokenizeAny(u8, "hello world", " ");
    _ = it.next();
}
ZIGEOF
)"

# -- Summary --

total=$((PASS_COUNT + FAIL_COUNT))
echo ""
printf "${BOLD}Summary${RESET}: %d probes, " "$total"
printf "${GREEN}%d confirmed${RESET}, " "$PASS_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
    printf "${RED}%d surprises${RESET}" "$FAIL_COUNT"
else
    printf "0 surprises"
fi
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo ""
    echo "Surprises indicate docs/ZIG_BREAKING_CHANGES-0.16.md needs updating."
    exit 1
fi
