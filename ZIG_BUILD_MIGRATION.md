# mruby Zig Build System Migration Plan

## Overview

This document outlines the plan to migrate mruby's build system from Rake to the Zig Build System, using `zig cc` as the C/C++ compiler.

## Current Rake Build System Analysis

### Build Phases

The current mruby build system (Rake-based) has the following key phases:

1. **Pre-Symbol Generation (Optional Optimization)**
   - Scans preprocessed C source files to extract symbols
   - Generates `presym_id.h` and `presym_table.h`
   - Reduces binary size and improves performance

2. **Core C Source Compilation**
   - Located in: `src/*.c`
   - ~33 source files
   - Special handling: `vm.c`, `error.c`, `gc.c` can be compiled as C++ when exceptions enabled
   - Produces: Object files for `libmruby_core.a`

3. **Compiler Sources**
   - Located in: `mrbgems/mruby-compiler/core/`
   - Includes: `codegen.c`, `parse.y` (processed by Bison)
   - Generates: Parser and code generator
   - Integrated into: `libmruby_core.a`

4. **mrblib (Ruby Standard Library)**
   - Located in: `mrblib/*.rb`
   - Process: Ruby files → mrbc compiler → `mrblib.c` (bytecode)
   - Generates: Single C file with embedded bytecode
   - Requires: `mrbc` binary to be built first

5. **mrbgems System**
   - 50+ gems in `mrbgems/`
   - Each gem has:
     - `mrbgem.rake`: Build configuration
     - `src/`: C/C++ sources
     - `mrblib/`: Ruby sources
     - `include/`: Public headers
     - `test/`: Test files
     - `bintest/`: Binary tests
     - `tools/`: Binary executables (e.g., mrbc, mruby, mirb)
   - Generates: `gem_init.c` to initialize all gems

6. **Library Building**
   - `libmruby_core.a`: Core + compiler (no gems)
   - `libmruby.a`: Core + mrblib + all gems

7. **Binary Executables**
   - `mrbc`: Compiler (requires only libmruby_core)
   - `mruby`: Interpreter (requires libmruby)
   - `mirb`: REPL (requires libmruby)
   - Additional binaries from gems

8. **Testing**
   - Unit tests: `mrbtest`
   - Binary tests: Ruby-based using test runner

### Build Configurations

The Rake system supports multiple build configurations:

- **Host build**: Native compilation
- **Cross builds**: For embedded targets, different architectures
- **Toolchains**: GCC, Clang, MSVC, MinGW, Emscripten, etc.
- **Options**: Debug, CXX exceptions, CXX ABI, no-float, etc.

### Dependencies Between Build Steps

```
1. parse.y → (bison) → parse.c
2. Core C sources + parse.c → libmruby_core.a
3. mrbc tool sources + libmruby_core.a → mrbc executable
4. mrblib/*.rb + mrbc → mrblib.c
5. mrblib.c → mrblib.o
6. Each gem:
   - gem/src/*.c → gem objects
   - gem/mrblib/*.rb + mrbc → gem bytecode C files → gem objects
7. All gem metadata → gem_init.c → gem_init.o
8. libmruby_core.a + mrblib.o + gem objects + gem_init.o → libmruby.a
9. mruby tool sources + libmruby.a → mruby executable
10. Other binaries similarly
```

## Zig Build System Design

### Advantages of Zig Build System

1. **Cross-compilation**: Built-in support for cross-compilation to many targets
2. **`zig cc`**: Drop-in replacement for gcc/clang with better cross-compilation
3. **Caching**: Automatic incremental builds with content-addressable cache
4. **Declarative**: Build graph is explicit and type-safe
5. **No external dependencies**: Just need Zig (no Ruby, Rake, Make, etc.)
6. **Speed**: Faster than traditional build systems due to parallelization

### Migration Strategy

#### Phase 1: Basic Structure (DONE)
- ✅ Created `build.zig` with basic structure
- ✅ Defined build phases
- ✅ Set up standard target and optimization options
- ✅ Updated to Zig 0.15.2 (latest stable release)

#### Phase 2: Core Compilation (TODO)
- [ ] Implement `buildLibmrubyCore()` fully
  - [ ] Handle all source files from `src/`
  - [ ] Add proper compiler flags
  - [ ] Support debug mode
  - [ ] Implement C++ exception mode (wrapper files)
- [ ] Generate `parse.c` from `parse.y` using Bison
  - Option 1: Pre-generate and check in
  - Option 2: Run Bison as build step
  - Option 3: Ship with pre-generated parse.c

#### Phase 3: Compiler and mrbc (TODO)
- [ ] Build `mrbc` executable
  - [ ] Link with libmruby_core
  - [ ] Add mrbc tool sources
- [ ] Create helper to run mrbc during build
  - [ ] Use `b.addRunArtifact(mrbc)` or system command

#### Phase 4: mrblib Compilation (TODO)
- [ ] Implement `buildMrblib()`
  - [ ] Discover all `.rb` files in `mrblib/`
  - [ ] Run `mrbc` to generate `mrblib.c`
  - [ ] Compile `mrblib.c` to object file
- [ ] Handle presym vs non-presym modes

#### Phase 5: mrbgems System (TODO)
- [ ] Design gem discovery mechanism
  - Option 1: Parse `mrbgem.rake` files (requires Ruby or parser)
  - Option 2: Create Zig configuration format (e.g., `mrbgem.zig.json`)
  - Option 3: Hardcode default gem set initially
- [ ] For each gem:
  - [ ] Compile C/C++ sources
  - [ ] Compile Ruby sources with mrbc
  - [ ] Handle dependencies between gems
  - [ ] Collect gem metadata
- [ ] Generate `gem_init.c`
  - [ ] Template-based generation
  - [ ] Include all gem init/final functions
- [ ] Generate `LEGAL` file

#### Phase 6: libmruby (TODO)
- [ ] Combine all object files:
  - [ ] libmruby_core objects
  - [ ] mrblib object
  - [ ] All gem objects
  - [ ] gem_init object
- [ ] Create static library
- [ ] Optionally create shared library (.so/.dylib/.dll)

#### Phase 7: Executables (TODO)
- [ ] Build `mruby` interpreter
- [ ] Build `mirb` REPL
- [ ] Build other gem binaries
- [ ] Install to `zig-out/bin/`

#### Phase 8: Header Installation (TODO)
- [ ] Install public headers from `include/`
- [ ] Install gem headers (from `include/mruby/gems/`)
- [ ] Generate configuration headers if needed

#### Phase 9: Testing (TODO)
- [ ] Build `mrbtest` executable
- [ ] Run unit tests
- [ ] Integrate bintest (may need external script)

#### Phase 10: Pre-Symbol Support (TODO)
- [ ] Implement presym preprocessing
- [ ] Generate symbol lists
- [ ] Generate presym headers
- [ ] Conditional compilation based on presym mode

#### Phase 11: Advanced Features (TODO)
- [ ] Multiple build configurations
- [ ] Cross-compilation support
- [ ] CXX exception/ABI modes
- [ ] Custom build configurations (like build_config/*.rb)
- [ ] Lockfile generation (gemlock)

## Implementation Details

### Using `zig cc`

All C/C++ compilation will use `zig cc` as the compiler:

```zig
const flags = [_][]const u8{
    "-std=c11",
    "-Wall",
    "-Wextra",
    // ... more flags
};

lib.addCSourceFiles(.{
    .files = &sources,
    .flags = &flags,
});
```

### Running mrbc During Build

To compile Ruby files to bytecode:

```zig
const mrbc_run = b.addRunArtifact(mrbc_exe);
mrbc_run.addArgs(&.{
    "-Bmrblib_irep",
    "-o",
});
const mrblib_c = mrbc_run.addOutputFileArg("mrblib.c");
mrbc_run.addFileArg(b.path("mrblib/array.rb"));
// ... add more .rb files

// Then compile the generated C file
const mrblib_obj = b.addObject(.{
    .name = "mrblib",
    .target = target,
    .optimize = optimize,
});
mrblib_obj.addCSourceFile(.{
    .file = mrblib_c,
    .flags = &flags,
});
```

### Code Generation

For generating files like `gem_init.c`:

```zig
const gen_step = b.addWriteFiles();
const gem_init_c = gen_step.add("gem_init.c", generated_content);

lib.addCSourceFile(.{
    .file = gem_init_c,
    .flags = &flags,
});
```

### Gem Configuration

Two approaches:

1. **Static Configuration** (Simpler, for Phase 1)
   ```zig
   const default_gems = [_][]const u8{
       "mruby-compiler",
       "mruby-bin-mrbc",
       "mruby-sprintf",
       // ... more gems
   };
   ```

2. **Dynamic Configuration** (Better, for Phase 2)
   - Create `build_config.zig.json` or similar
   - Parse gem metadata at comptime
   - Or use Zig comptime to read gem directories

## Testing Strategy

1. **Unit Tests**: Start with basic compilation test
   ```bash
   zig build
   ./zig-out/bin/mrbc --version
   ./zig-out/bin/mruby --version
   ```

2. **Comparison Testing**: Compare against Rake build
   - Binary sizes
   - Test suite results
   - Performance benchmarks

3. **CI Integration**:
   - Add Zig build to GitHub Actions
   - Run alongside Rake build initially
   - Eventually replace Rake build

## Migration Checklist

### Milestone 1: Minimal Build
- [ ] Compile core sources
- [ ] Build libmruby_core.a
- [ ] Build mrbc executable
- [ ] Verify mrbc works

### Milestone 2: Complete Core
- [ ] Compile mrblib
- [ ] Build minimal libmruby.a (core + mrblib, no gems)
- [ ] Build mruby executable
- [ ] Run basic Ruby code

### Milestone 3: Gem Support
- [ ] Add default gem set
- [ ] Generate gem_init.c
- [ ] Build libmruby.a with gems
- [ ] Run mruby test suite

### Milestone 4: Feature Complete
- [ ] All binaries build (mruby, mrbc, mirb, etc.)
- [ ] Pre-symbol optimization works
- [ ] Tests pass
- [ ] Cross-compilation works

### Milestone 5: Production Ready
- [ ] Documentation complete
- [ ] CI integrated
- [ ] Performance comparable to Rake build
- [ ] All platforms supported

## Build Command Examples

```bash
# Basic build (debug)
zig build

# Release build
zig build -Doptimize=ReleaseFast

# With debug symbols
zig build -Denable-debug=true

# Cross-compile for Windows from Linux
zig build -Dtarget=x86_64-windows

# Cross-compile for ARM
zig build -Dtarget=aarch64-linux

# Build and run tests
zig build test

# Install to custom prefix
zig build -Dprefix=/usr/local install
```

## Comparison: Rake vs Zig Build

| Aspect | Rake | Zig Build |
|--------|------|-----------|
| **Language** | Ruby | Zig |
| **Dependencies** | Ruby, Rake gem | Just Zig |
| **Cross-compilation** | Manual toolchain setup | Built-in |
| **Caching** | Rake's timestamp-based | Content-addressable |
| **Speed** | Moderate | Fast (parallel by default) |
| **Configuration** | Ruby DSL (.rb files) | Zig code (.zig files) |
| **Learning Curve** | Medium (need Ruby knowledge) | Medium (need Zig basics) |
| **Maintenance** | Complex (many .rake files) | Simpler (single build.zig) |

## Challenges and Solutions

### Challenge 1: Parsing mrbgem.rake Files
**Problem**: Gem configuration is in Ruby
**Solution**:
- Short-term: Hardcode default gems
- Long-term: Create JSON/TOML configuration or Zig parser

### Challenge 2: Running mrbc During Build
**Problem**: Need to compile Ruby to bytecode
**Solution**: Use `b.addRunArtifact()` to run mrbc as a build step

### Challenge 3: Pre-Symbol Generation
**Problem**: Complex preprocessing step
**Solution**:
- Phase 1: Disable presym (use -DMRB_NO_PRESYM)
- Phase 2: Implement presym scanning in Zig or as external tool

### Challenge 4: C++ Exception Mode
**Problem**: Some files need to be compiled as C++
**Solution**: Generate wrapper .cpp files during build

### Challenge 5: Parse.y Processing
**Problem**: Need Bison to generate parser
**Solution**:
- Check in pre-generated parse.c
- Or run bison as build step if available

## Next Steps

1. ✅ Create initial `build.zig` structure
2. ✅ Document migration plan
3. **Implement Phase 2**: Core compilation
4. **Implement Phase 3**: mrbc building
5. Test minimal build
6. Continue with subsequent phases

## References

- [Zig Build System Documentation](https://ziglang.org/learn/build-system/)
- [mruby GitHub Repository](https://github.com/mruby/mruby)
- Current build system: `Rakefile`, `lib/mruby/build.rb`, `tasks/*.rake`
- GitHub Actions: `.github/workflows/build.yml`
