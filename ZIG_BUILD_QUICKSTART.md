# Zig Build Quick Start Guide

## Prerequisites

1. Install Zig (version 0.15.2 or later)
   ```bash
   # Download from https://ziglang.org/download/
   # Or use a package manager:
   # - macOS: brew install zig
   # - Linux: See distro-specific instructions
   # - Windows: Use installer or package manager
   ```

2. Verify installation:
   ```bash
   zig version
   # Should show: 0.15.2 or later
   ```

## Building mruby with Zig

### Basic Build

```bash
# Build with default settings (Debug mode)
zig build

# Outputs will be in: zig-out/bin/
```

### Build Options

```bash
# Release build (optimized)
zig build -Doptimize=ReleaseFast

# Release with safety checks
zig build -Doptimize=ReleaseSafe

# Small binary size
zig build -Doptimize=ReleaseSmall

# Enable debug mode (MRB_DEBUG)
zig build -Denable-debug=true

# Disable pre-symbol optimization
zig build -Ddisable-presym=true

# Enable C++ exceptions
zig build -Denable-cxx-exception=true

# Enable C++ ABI
zig build -Denable-cxx-abi=true
```

### Cross-Compilation

One of Zig's superpowers is easy cross-compilation:

```bash
# Cross-compile for Windows from Linux/macOS
zig build -Dtarget=x86_64-windows-gnu

# Cross-compile for Linux from any platform
zig build -Dtarget=x86_64-linux-gnu

# Cross-compile for macOS
zig build -Dtarget=aarch64-macos

# Cross-compile for ARM Linux (e.g., Raspberry Pi)
zig build -Dtarget=aarch64-linux-gnu
zig build -Dtarget=armv7-linux-gnueabihf

# Cross-compile for embedded (bare metal)
zig build -Dtarget=arm-freestanding-eabi
```

### Installation

```bash
# Install to default location (zig-out/)
zig build install

# Install to custom prefix
zig build install --prefix /usr/local

# Or set prefix via environment
PREFIX=/opt/mruby zig build install
```

## Using the Built Binaries

```bash
# Run the interpreter
./zig-out/bin/mruby -e 'puts "Hello from mruby!"'

# Compile a Ruby file to bytecode
./zig-out/bin/mrbc example.rb

# Start the REPL
./zig-out/bin/mirb
```

## Comparing Build Times

```bash
# Time the Zig build
time zig build -Doptimize=ReleaseFast

# Time the Rake build (for comparison)
time rake
```

## Troubleshooting

### Build Fails with "parse.c not found"

The parser needs to be generated from parse.y:

```bash
# Option 1: Use pre-generated parse.c (if available)
# It should be in mrbgems/mruby-compiler/core/parse.c

# Option 2: Generate it with Bison
cd mrbgems/mruby-compiler/core
bison -o parse.c parse.y
cd ../../..
zig build
```

### Zig Version Too Old

Make sure you have Zig 0.15.2 or later:

```bash
zig version
# Upgrade if needed
```

### Permission Denied on Linux/macOS

The build might need permissions to write to build directories:

```bash
# Make sure you have write access
ls -la zig-cache zig-out

# Or clean and rebuild
rm -rf zig-cache zig-out
zig build
```

## Development Workflow

### Clean Build

```bash
# Remove build artifacts
rm -rf zig-cache zig-out

# Or use the clean command (if implemented)
zig build clean
```

### Incremental Build

Zig's build system automatically handles incremental builds:

```bash
# First build (slower)
zig build

# Subsequent builds (much faster, only rebuilds changed files)
zig build
```

### Verbose Build

```bash
# See all commands being run
zig build --verbose
```

### Build Specific Target

```bash
# Build only mrbc
zig build mrbc

# Build only libmruby
zig build libmruby
```

## Build System Architecture

The Zig build system compiles mruby in these phases:

1. **Parse.y → Parse.c**: Generate parser (if not pre-generated)
2. **Core Sources → libmruby_core.a**: Compile core mruby + compiler
3. **mrbc Tool + libmruby_core.a → mrbc**: Build the compiler executable
4. **mrblib/*.rb + mrbc → mrblib.c**: Compile Ruby stdlib to bytecode
5. **Gems**: Compile all active mrbgems (C sources and Ruby sources)
6. **gem_init.c**: Generate gem initialization code
7. **libmruby.a**: Combine core + mrblib + gems
8. **Executables**: Build mruby, mirb, and other binaries

## Advanced Usage

### Custom Build Configuration

Edit `build.zig` to customize:
- Which gems to include
- Compiler flags
- Target-specific settings
- Custom build steps

### Using as a Zig Package

If you want to use mruby as a dependency in another Zig project:

```zig
// In your build.zig.zon
.dependencies = .{
    .mruby = .{
        .url = "https://github.com/mruby/mruby/archive/refs/tags/3.4.0.tar.gz",
        .hash = "...", // zig build will tell you the hash
    },
},

// In your build.zig
const mruby = b.dependency("mruby", .{
    .target = target,
    .optimize = optimize,
});
exe.linkLibrary(mruby.artifact("mruby"));
```

## Migrating from Rake

| Rake Command | Zig Equivalent |
|--------------|----------------|
| `rake` | `zig build` |
| `rake all` | `zig build` |
| `rake clean` | `rm -rf zig-cache zig-out` |
| `rake test` | `zig build test` (when implemented) |
| `MRUBY_CONFIG=host-debug rake` | `zig build -Denable-debug=true` |
| `CC=clang rake` | `zig build` (uses zig cc) |
| `make` | `zig build` |

## Performance Tips

1. **Use Release Builds for Benchmarks**:
   ```bash
   zig build -Doptimize=ReleaseFast
   ```

2. **Parallel Builds**: Zig parallelizes automatically, but you can limit:
   ```bash
   zig build -j4  # Use 4 cores
   ```

3. **Cache Reuse**: The `zig-cache/` directory speeds up rebuilds, keep it!

4. **Incremental Builds**: Don't clean unless necessary

## Getting Help

- Zig Build System Docs: https://ziglang.org/learn/build-system/
- Zig Community: https://ziglang.org/community/
- mruby Documentation: https://github.com/mruby/mruby/tree/master/doc
- Migration Plan: See `ZIG_BUILD_MIGRATION.md`

## Current Status

This Zig build system is currently **under development**. Status:

- ✅ Basic structure in place
- ✅ Build system designed
- ✅ Migration plan documented
- ⏳ Core compilation (in progress)
- ⏳ mrbc building (in progress)
- ⏳ mrblib compilation (pending)
- ⏳ Gem system (pending)
- ⏳ Full feature parity with Rake (pending)

Check `ZIG_BUILD_MIGRATION.md` for detailed implementation status.
