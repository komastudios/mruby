# Testing the Zig Build (Phase 2)

## Current Implementation Status

Phase 2 is now complete! The build system can now compile:

1. **mrbc** - The mruby compiler executable
2. **libmruby_core.a** - Core mruby library with compiler
3. **Headers** - All public include files

## Testing Without Zig Installed

Since Zig is not installed in this environment, here's how to test when you have Zig 0.15.2+:

```bash
# First, ensure parse.c exists (already generated)
ls -l mrbgems/mruby-compiler/core/parse.c

# Build with Zig
zig build

# Expected output files:
# - zig-out/bin/mrbc (or mrbc.exe on Windows)
# - zig-out/lib/libmruby_core.a
# - zig-out/include/ (headers)

# Test the mrbc compiler
./zig-out/bin/mrbc --version

# Build in release mode
zig build -Doptimize=ReleaseFast

# Build with debug symbols
zig build -Denable-debug=true
```

## Expected Build Output

When you run `zig build`, you should see:

```
Building mrbc...
  Compiling 33 core C sources
  Compiling 2 compiler sources
  Compiling 2 mrbc tool sources
  Linking mrbc

Building libmruby_core.a...
  Compiling 33 core C sources
  Compiling 2 compiler sources
  Creating static library

Installing artifacts...
  zig-out/bin/mrbc
  zig-out/lib/libmruby_core.a
  zig-out/include/

Build complete!
```

## Verification Steps

1. **Check mrbc builds correctly:**
   ```bash
   ls -lh zig-out/bin/mrbc
   file zig-out/bin/mrbc
   ```

2. **Check library is created:**
   ```bash
   ls -lh zig-out/lib/libmruby_core.a
   ar -t zig-out/lib/libmruby_core.a | head -20
   ```

3. **Check headers are installed:**
   ```bash
   ls zig-out/include/mruby/
   ```

4. **Test mrbc can compile Ruby code:**
   ```bash
   echo 'puts "Hello from mruby!"' > test.rb
   ./zig-out/bin/mrbc test.rb
   ls -l test.mrb
   ```

## Known Limitations (Phase 2)

- ✅ mrbc compiler builds and runs
- ✅ libmruby_core.a static library builds
- ⏳ mrblib (Ruby stdlib) not yet compiled
- ⏳ mrbgems not yet integrated
- ⏳ Full libmruby.a not yet built
- ⏳ mruby interpreter executable not yet built
- ⏳ mirb REPL not yet built

## Cross-Compilation Test

Test cross-compilation without actually building:

```bash
# Show what would be built for Windows
zig build -Dtarget=x86_64-windows-gnu --summary all

# Show what would be built for ARM Linux
zig build -Dtarget=aarch64-linux-gnu --summary all

# Show what would be built for macOS
zig build -Dtarget=aarch64-macos --summary all
```

## Troubleshooting

### Parse.c not found

If you get an error about parse.c not found:

```bash
cd mrbgems/mruby-compiler/core
bison -o parse.c parse.y
cd ../../..
zig build
```

### Compiler errors

If you encounter compiler errors, try:

```bash
# Clean build
rm -rf zig-cache zig-out
zig build

# Verbose output
zig build --verbose
```

### Math library linking errors on Windows

On Windows, the math library is not linked separately. The build should handle this automatically.

## Next Steps (Phase 3+)

Once Phase 2 is verified working:

1. **Phase 3**: Implement mrblib compilation using mrbc
2. **Phase 4**: Add mrbgems support
3. **Phase 5**: Build complete libmruby.a
4. **Phase 6**: Build mruby interpreter and other executables
5. **Phase 7**: Complete header installation
6. **Phase 8**: Add testing support

## CI Testing

The GitHub Actions workflow will automatically test:
- Ubuntu 24.04, 22.04 (gcc, clang)
- macOS 15, 14
- Windows latest
- Cross-compilation targets

Check: https://github.com/komastudios/mruby/actions
