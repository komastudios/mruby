const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build configuration options
    const enable_debug = b.option(bool, "enable-debug", "Enable debug mode (MRB_DEBUG)") orelse false;
    const enable_cxx_exception = b.option(bool, "enable-cxx-exception", "Enable C++ exceptions") orelse false;
    const enable_cxx_abi = b.option(bool, "enable-cxx-abi", "Enable C++ ABI") orelse false;
    const disable_presym = b.option(bool, "disable-presym", "Disable pre-symbol optimization") orelse false;

    // ========================================================================
    // PHASE 1: Build mrbc compiler (needed for compiling Ruby files)
    // ========================================================================

    const mrbc_exe = buildMrbcCompiler(b, target, optimize, enable_debug);
    _ = mrbc_exe; // Will be used in Phase 3 for mrblib compilation

    // ========================================================================
    // PHASE 2: Build libmruby_core.a
    // ========================================================================

    const libmruby_core = buildLibmrubyCore(b, target, optimize, enable_debug, enable_cxx_exception, enable_cxx_abi);
    b.installArtifact(libmruby_core);

    // ========================================================================
    // PHASE 3: Build mrblib (Ruby standard library compiled to bytecode)
    // ========================================================================

    // TODO: Implement presym generation if needed
    _ = disable_presym; // suppress unused variable warning

    // TODO: Implement mrblib compilation
    // const mrblib_obj = buildMrblib(b, target, optimize, mrbc_exe, disable_presym);

    // ========================================================================
    // PHASE 4: Build mrbgems
    // ========================================================================

    // TODO: Implement mrbgem discovery and compilation

    // ========================================================================
    // PHASE 5: Build libmruby.a (core + mrblib + gems)
    // ========================================================================

    // TODO: Build complete libmruby
    // const libmruby = buildLibmruby(b, target, optimize, libmruby_core, mrblib_obj, gem_init_obj);
    // b.installArtifact(libmruby);

    // ========================================================================
    // PHASE 6: Build executables (mruby, mirb, etc.)
    // ========================================================================

    // TODO: Build mruby executable
    // buildMrubyExecutable(b, target, optimize, libmruby);

    // ========================================================================
    // PHASE 7: Install headers
    // ========================================================================

    installHeaders(b);

    // ========================================================================
    // Testing
    // ========================================================================

    // TODO: Implement test building and running
    // - Build mrbtest
    // - Run unit tests
    // - Run bintests
}

fn buildMrbcCompiler(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    enable_debug: bool,
) *std.Build.Step.Compile {
    const mrbc = b.addExecutable(.{
        .name = "mrbc",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    // Build compiler flags
    var flags = std.ArrayList([]const u8).init(b.allocator);

    // Standard C flags
    flags.append("-std=gnu99") catch @panic("OOM");
    flags.append("-Wall") catch @panic("OOM");
    flags.append("-Wundef") catch @panic("OOM");
    flags.append("-Werror-implicit-function-declaration") catch @panic("OOM");
    flags.append("-Wwrite-strings") catch @panic("OOM");

    // Debug or optimization flags
    if (enable_debug) {
        flags.append("-DMRB_DEBUG") catch @panic("OOM");
        flags.append("-g3") catch @panic("OOM");
        flags.append("-O0") catch @panic("OOM");
    } else {
        flags.append("-g") catch @panic("OOM");
        flags.append("-O3") catch @panic("OOM");
    }

    // mrbc-specific defines
    flags.append("-DMRB_NO_PRESYM") catch @panic("OOM");
    flags.append("-DMRB_NO_GEMS") catch @panic("OOM");

    // Core sources needed for mrbc (alphabetically sorted)
    const core_sources = [_][]const u8{
        "src/allocf.c",
        "src/array.c",
        "src/backtrace.c",
        "src/cdump.c",
        "src/class.c",
        "src/codedump.c",
        "src/debug.c",
        "src/dump.c",
        "src/enum.c",
        "src/error.c",
        "src/etc.c",
        "src/fmt_fp.c",
        "src/gc.c",
        "src/hash.c",
        "src/init.c",
        "src/kernel.c",
        "src/load.c",
        "src/mempool.c",
        "src/numeric.c",
        "src/numops.c",
        "src/object.c",
        "src/print.c",
        "src/proc.c",
        "src/range.c",
        "src/readfloat.c",
        "src/readint.c",
        "src/readnum.c",
        "src/state.c",
        "src/string.c",
        "src/symbol.c",
        "src/variable.c",
        "src/version.c",
        "src/vm.c",
    };

    mrbc.addCSourceFiles(.{
        .files = &core_sources,
        .flags = flags.items,
    });

    // Add compiler sources
    const compiler_sources = [_][]const u8{
        "mrbgems/mruby-compiler/core/codegen.c",
        "mrbgems/mruby-compiler/core/parse.c", // Generated from parse.y
    };

    mrbc.addCSourceFiles(.{
        .files = &compiler_sources,
        .flags = flags.items,
    });

    // Add mrbc tool sources
    const mrbc_tool_sources = [_][]const u8{
        "mrbgems/mruby-bin-mrbc/tools/mrbc/mrbc.c",
        "mrbgems/mruby-bin-mrbc/tools/mrbc/stub.c",
    };

    mrbc.addCSourceFiles(.{
        .files = &mrbc_tool_sources,
        .flags = flags.items,
    });

    // Include paths
    mrbc.addIncludePath(b.path("include"));
    mrbc.addIncludePath(b.path("mrbgems/mruby-compiler/core"));

    // Link with libc and libm
    mrbc.linkLibC();
    if (target.result.os.tag != .windows) {
        mrbc.linkSystemLibrary("m");
    }

    b.installArtifact(mrbc);

    return mrbc;
}

fn buildLibmrubyCore(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    enable_debug: bool,
    enable_cxx_exception: bool,
    enable_cxx_abi: bool,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mruby_core",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    // Build compiler flags based on Rake toolchain settings (gcc.rake)
    var flags = std.ArrayList([]const u8).init(b.allocator);

    // Standard C flags
    flags.append("-std=gnu99") catch @panic("OOM");
    flags.append("-Wall") catch @panic("OOM");
    flags.append("-Wundef") catch @panic("OOM");
    flags.append("-Werror-implicit-function-declaration") catch @panic("OOM");
    flags.append("-Wwrite-strings") catch @panic("OOM");

    // Debug or optimization flags
    if (enable_debug) {
        flags.append("-DMRB_DEBUG") catch @panic("OOM");
        flags.append("-g3") catch @panic("OOM");
        flags.append("-O0") catch @panic("OOM");
    } else {
        flags.append("-g") catch @panic("OOM");
        flags.append("-O3") catch @panic("OOM");
    }

    // C++ exception/ABI flags
    if (enable_cxx_exception or enable_cxx_abi) {
        flags.append("-DMRB_USE_CXX_EXCEPTION") catch @panic("OOM");
    }
    if (enable_cxx_abi) {
        flags.append("-DMRB_USE_CXX_ABI") catch @panic("OOM");
    }

    // Core sources (all files from src/, alphabetically sorted)
    const sources = [_][]const u8{
        "src/allocf.c",
        "src/array.c",
        "src/backtrace.c",
        "src/cdump.c",
        "src/class.c",
        "src/codedump.c",
        "src/debug.c",
        "src/dump.c",
        "src/enum.c",
        "src/error.c",
        "src/etc.c",
        "src/fmt_fp.c",
        "src/gc.c",
        "src/hash.c",
        "src/init.c",
        "src/kernel.c",
        "src/load.c",
        "src/mempool.c",
        "src/numeric.c",
        "src/numops.c",
        "src/object.c",
        "src/print.c",
        "src/proc.c",
        "src/range.c",
        "src/readfloat.c",
        "src/readint.c",
        "src/readnum.c",
        "src/state.c",
        "src/string.c",
        "src/symbol.c",
        "src/variable.c",
        "src/version.c",
        "src/vm.c",
    };

    // Note: vm.c, error.c, gc.c would need special C++ compilation
    // when enable_cxx_exception or enable_cxx_abi is true.
    // For now, we compile everything as C. TODO: Add C++ wrapper support.

    lib.addCSourceFiles(.{
        .files = &sources,
        .flags = flags.items,
    });

    // Add compiler sources
    const compiler_sources = [_][]const u8{
        "mrbgems/mruby-compiler/core/codegen.c",
        "mrbgems/mruby-compiler/core/parse.c", // Generated from parse.y
    };

    lib.addCSourceFiles(.{
        .files = &compiler_sources,
        .flags = flags.items,
    });

    // Include paths
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("mrbgems/mruby-compiler/core"));

    // Link with libc and libm (math library)
    lib.linkLibC();
    if (target.result.os.tag != .windows) {
        lib.linkSystemLibrary("m");
    }

    return lib;
}

fn buildMrblib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mrbc_exe: *std.Build.Step.Compile,
    disable_presym: bool,
) *std.Build.Step.Compile {
    _ = b;
    _ = target;
    _ = optimize;
    _ = mrbc_exe;
    _ = disable_presym;

    // TODO: Implement mrblib compilation
    // 1. Find all .rb files in mrblib/
    // 2. Run mrbc on them to generate mrblib.c
    // 3. Compile mrblib.c to object file
    // 4. Return the compiled object

    // For now, return a dummy compile step
    @panic("buildMrblib not yet implemented");
}

fn buildGemInit(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    _ = b;
    _ = target;
    _ = optimize;

    // TODO: Implement gem_init.c generation
    // 1. Discover all active gems
    // 2. Generate gem_init.c with initialization functions
    // 3. Compile it

    @panic("buildGemInit not yet implemented");
}

fn buildLibmruby(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    libmruby_core: *std.Build.Step.Compile,
    mrblib_obj: *std.Build.Step.Compile,
    gem_init_obj: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    _ = mrblib_obj;
    _ = gem_init_obj;

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "mruby",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link libmruby_core
    lib.linkLibrary(libmruby_core);

    // TODO: Add mrblib object
    // TODO: Add gem objects
    // TODO: Add gem_init object

    lib.addIncludePath(b.path("include"));
    lib.linkLibC();

    return lib;
}

fn buildMrubyExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    libmruby: *std.Build.Step.Compile,
) void {
    _ = libmruby;

    const exe = b.addExecutable(.{
        .name = "mruby",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    // TODO: Add mruby binary sources
    // TODO: Link with libmruby

    exe.addIncludePath(b.path("include"));
    exe.linkLibC();

    b.installArtifact(exe);
}

fn installHeaders(b: *std.Build) void {
    // Install public headers
    const include_dir = b.path("include");
    b.installDirectory(.{
        .source_dir = include_dir,
        .install_dir = .header,
        .install_subdir = "",
    });
}
