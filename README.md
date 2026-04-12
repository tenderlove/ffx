# FFX

FFX transpiles Ruby FFI definitions into C extensions with embedded type hints
for ZJIT.

You write standard Ruby FFI (`extend FFI::Library`, `attach_function`, etc.),
and at `gem install` time FFX converts those definitions into a compiled C
extension.  The generated extension includes a trampoline for each function
that smuggles parameter and return type metadata right after an unconditional
branch to the real implementation.  ZJIT can read this metadata and generate
specialized native calls — skipping the generic cfunc dispatch path entirely.

On JRuby and TruffleRuby the C extension is ignored and the original FFI code
is used as-is, so gems that use FFX stay portable.

## Usage

1. Copy `ffx.rb` and `ffi.rb` (the empty stub) into your extension directory
   (e.g. `ext/mylib/`).

2. Write your FFI definitions in a Ruby file in the same directory:

   ```ruby
   # ext/mylib/mylib.rb
   require "ffi"

   module MyLib
     extend FFI::Library
     ffi_lib "c"

     attach_function :strlen, [:string], :size_t
   end
   ```

3. Use FFX in your `extconf.rb` instead of `mkmf` directly:

   ```ruby
   # ext/mylib/extconf.rb
   require_relative "ffx"
   FFX.create_makefile("mylib", File.expand_path("mylib.rb", __dir__))
   ```

That's it.  `gem install` will transpile the FFI definitions into C, compile
the extension, and install it.

## Supported types

`void`, `int`, `uint`, `long`, `size_t`, `float`, `double`, `string`, `pointer`

## How it works

For each `attach_function` call, FFX generates:

- An **impl** function that marshals Ruby values to C, calls the native
  function, and marshals the result back.
- A **trampoline** (a `naked` function) registered with
  `rb_define_module_function`.  It starts with a branch to the impl, followed
  by a magic marker (`0x46464930` / "FFI0"), parameter/return type bytes, and
  the native function name.

Normal calls hit the branch and jump straight to the impl — the metadata is
never executed.  When ZJIT compiles a call to the trampoline, it checks for the
magic marker, reads the type info, and emits a direct call to the native
function with inlined type conversions, bypassing the wrapper entirely.
