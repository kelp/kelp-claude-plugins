# Zig 0.15.x Breaking Changes - Training Override Sheet

This document corrects Claude's outdated training data with
current Zig 0.15.x reality. It covers only the patterns that
models consistently get wrong in blind testing.

## Quick Reference Table

| What Claude Thinks | Reality in 0.15.x | Quick Fix |
|---|---|---|
| `std.io.getStdOut().writer()` | REMOVED (Writergate) | Buffered writer pattern (see below) |
| `std.io.getStdErr().writer()` | REMOVED (Writergate) | Buffered writer pattern (see below) |
| `usingnamespace` keyword exists | REMOVED from language | Zero-bit fields + `@fieldParentPtr` |
| `std.ArrayList(T).init(allocator)` | Managed API removed | `std.ArrayListUnmanaged(T){}`, pass allocator to methods |
| `std.BoundedArray` exists | REMOVED | `ArrayListUnmanaged.initBuffer(&buffer)` |
| `{}` in format strings calls format | Ambiguous -- compile error | Use `{f}` to call format methods |
| Generic writers with `anytype` | Concrete `std.Io.Writer` type | Non-generic with buffer in interface |
| `std.io.BufferedWriter` exists | REMOVED | Writers have built-in buffering |
| Build uses `.root_source_file` | Moved inside `.root_module` | `b.createModule(.{ .root_source_file = ... })` |

## Error Messages That Mean Your Training Is Wrong

```
"no member named 'getStdOut'"
-> Writergate happened - see I/O pattern below

"no member named 'getStdErr'"
-> Writergate happened - see I/O pattern below

"no field named 'root_source_file'"
-> Build system changed - use .root_module = b.createModule(...)

"ambiguous format string; specify {f} to call format method"
-> Must use {f} not {} for format methods

"expected 2 arguments, found 1"
-> ArrayList methods need allocator parameter now

"no member named 'init'"
-> ArrayList is unmanaged - use {} or initCapacity(allocator, 0)

"usingnamespace is deprecated"
-> It's not deprecated, it's GONE - refactor completely

"no field named 'writer'"
-> Likely std.fs.File - use new buffered writer pattern

"error: no member named 'allocator'"
-> ArrayList is unmanaged - pass allocator to methods
```

## Critical Code Patterns

### I/O Pattern (Writergate) -- Memorize This

```zig
// WRONG (your training)
const stdout = std.io.getStdOut().writer();
try stdout.print("Hello, {}\n", .{world});

// RIGHT (Zig 0.15.x)
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
defer stdout.flush() catch {};  // DON'T FORGET TO FLUSH!
try stdout.print("Hello, {s}\n", .{world});
```

### ArrayList Pattern

```zig
// WRONG (your training)
var list = std.ArrayList(u32).init(allocator);
defer list.deinit();
try list.append(42);

// RIGHT (Zig 0.15.x)
var list = std.ArrayListUnmanaged(u32){};
defer list.deinit(allocator);  // allocator needed
try list.append(allocator, 42);  // allocator needed
```

### Format Method Pattern

```zig
// WRONG (your training)
pub fn format(value: T, comptime fmt: []const u8,
    options: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("{}", .{value.field});
}

// RIGHT (Zig 0.15.x)
pub fn format(value: T, writer: *std.Io.Writer)
    std.Io.Writer.Error!void {
    try writer.print("{d}", .{value.field});
}
```

Use `{f}` in format strings to call format methods, not `{}`.

### Mixin Pattern (replacing usingnamespace)

```zig
// WRONG (your training)
const Foo = struct {
    data: u32,
    pub usingnamespace Mixin(Foo);
};

// RIGHT (Zig 0.15.x)
const Foo = struct {
    data: u32,
    mixin: Mixin(Foo) = .{},  // zero-bit field
};

pub fn Mixin(comptime T: type) type {
    return struct {
        pub fn method(m: *@This()) void {
            const self: *T = @alignCast(
                @fieldParentPtr("mixin", m),
            );
            self.data += 1;
        }
    };
}
// Usage: foo.mixin.method() instead of foo.method()
```

### BoundedArray Replacement

```zig
// WRONG (your training)
var stack = try std.BoundedArray(i32, 8).fromSlice(initial);

// RIGHT (Zig 0.15.x)
var buffer: [8]i32 = undefined;
var stack = std.ArrayListUnmanaged(i32).initBuffer(&buffer);
try stack.appendSliceBounded(initial);
```

### Build System Pattern

```zig
// WRONG (your training)
const exe = b.addExecutable(.{
    .name = "app",
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});

// RIGHT (Zig 0.15.x)
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

## Migration Strategies

### Writergate Migration
1. Add buffer array before writer creation
2. Create writer with `.writer(&buffer)`
3. Use `&writer.interface` to get `*std.Io.Writer`
4. Always `defer flush()` or data may be lost

### ArrayList Migration
1. Replace `ArrayList(T)` with `ArrayListUnmanaged(T)`
2. Initialize with `{}` not `.init(allocator)`
3. Add allocator parameter to ALL method calls
4. If you need managed: `std.array_list.Managed(T)`

### usingnamespace Migration
1. For conditional inclusion: compile-time conditionals
2. For mixins: zero-bit fields with `@fieldParentPtr`
3. For implementation switching: conditional public decls

### Format String Migration
1. Replace `{}` with explicit format specifiers
2. Use `{f}` to explicitly call format methods
3. Use `{s}` for strings, `{d}` for decimals
4. Use `{any}` to skip format methods

## Features That Are GONE

These aren't deprecated, they're DELETED:
- `usingnamespace` keyword
- `async`/`await` keywords
- `@frameSize` builtin
- `std.io.getStdOut/In/Err`
- `std.BoundedArray`
- `std.fifo.LinearFifo`
- `std.io.BufferedWriter/Reader`
- `std.io.CountingWriter`
- Generic `std.DoublyLinkedList(T)`

## Quick Diagnostics

### "Why doesn't this compile?"
1. Check if it uses removed features (usingnamespace, async,
   BoundedArray)
2. Check if it's missing allocator parameters (ArrayList)
3. Check if it's using old I/O patterns (getStdOut)
4. Check if format strings need specifiers ({} -> {s}, {d}, {f})

### "Why does this crash?"
1. Unflushed writer buffers
2. Arithmetic on undefined values
3. Memory not freed (if using argsAlloc, etc.)

## When You're Stuck

1. Check error message against the table above
2. Grep working code in `src/` for similar patterns
3. Check project Zig documentation for current syntax

The language changed fundamentally. Your instincts are wrong.
Always verify.
