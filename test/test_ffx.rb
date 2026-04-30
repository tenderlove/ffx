require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "rbconfig"

class TestFFX < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  DLEXT = RbConfig::CONFIG["DLEXT"]

  def test_strlen_end_to_end
    Dir.mktmpdir do |tmpdir|
      FileUtils.cp(File.join(ROOT, "ffx.rb"), tmpdir)
      FileUtils.cp(File.join(ROOT, "ffi.rb"), tmpdir)

      File.write(File.join(tmpdir, "mylib.rb"), <<~RUBY)
        require "ffi"

        module MyLib
          extend FFI::Library
          ffi_lib "c"

          attach_function :strlen, [:string], :size_t
        end
      RUBY

      File.write(File.join(tmpdir, "extconf.rb"), <<~RUBY)
        require_relative "ffx"
        FFX.create_makefile("mylib", File.expand_path("mylib.rb", __dir__))
      RUBY

      build_extension(tmpdir)

      ext_path = File.join(tmpdir, "mylib.#{DLEXT}")
      out = run_ruby(tmpdir, <<~RUBY)
        require "#{ext_path}"
        puts MyLib.strlen("hello")
      RUBY

      assert_equal "5", out.strip
    end
  end

  def test_bool_char_uchar_round_trip
    Dir.mktmpdir do |tmpdir|
      FileUtils.cp(File.join(ROOT, "ffx.rb"), tmpdir)
      FileUtils.cp(File.join(ROOT, "ffi.rb"), tmpdir)

      File.write(File.join(tmpdir, "ffxtest.h"), <<~C)
        #pragma once
        #include <stdbool.h>

        static inline bool          ffxtest_not_bool(bool b)         { return !b; }
        static inline char          ffxtest_inc_char(char c)         { return (char)(c + 1); }
        static inline unsigned char ffxtest_inc_uchar(unsigned char c){ return (unsigned char)(c + 1); }
      C

      File.write(File.join(tmpdir, "mylib.rb"), <<~RUBY)
        require "ffi"

        module MyLib
          extend FFI::Library
          ffi_lib "c"

          attach_function :ffxtest_not_bool,  [:bool],  :bool
          attach_function :ffxtest_inc_char,  [:char],  :char
          attach_function :ffxtest_inc_uchar, [:uchar], :uchar
        end
      RUBY

      File.write(File.join(tmpdir, "extconf.rb"), <<~RUBY)
        require "mkmf"
        $INCFLAGS << " -I" << __dir__
        require_relative "ffx"
        FFX.create_makefile("mylib", File.expand_path("mylib.rb", __dir__),
                            headers: ["ffxtest.h"])
      RUBY

      build_extension(tmpdir)

      ext_path = File.join(tmpdir, "mylib.#{DLEXT}")
      out = run_ruby(tmpdir, <<~RUBY)
        require "#{ext_path}"
        puts MyLib.ffxtest_not_bool(true).inspect
        puts MyLib.ffxtest_not_bool(false).inspect
        puts MyLib.ffxtest_not_bool(nil).inspect
        puts MyLib.ffxtest_inc_char(65)
        puts MyLib.ffxtest_inc_uchar(254)
      RUBY

      lines = out.lines.map(&:chomp)
      assert_equal "false", lines[0]
      assert_equal "true",  lines[1]
      assert_equal "true",  lines[2]   # nil is RTEST-falsy → !false → true
      assert_equal "66",    lines[3]   # 'A' + 1 == 'B'
      assert_equal "255",   lines[4]
    end
  end

  def test_remaining_primitives_round_trip
    Dir.mktmpdir do |tmpdir|
      FileUtils.cp(File.join(ROOT, "ffx.rb"), tmpdir)
      FileUtils.cp(File.join(ROOT, "ffi.rb"), tmpdir)

      File.write(File.join(tmpdir, "ffxtest.h"), <<~C)
        #pragma once
        #include <stdint.h>

        static inline short              ffxtest_inc_short(short s)              { return (short)(s + 1); }
        static inline unsigned short     ffxtest_inc_ushort(unsigned short s)    { return (unsigned short)(s + 1); }
        static inline int8_t             ffxtest_inc_int8(int8_t n)              { return (int8_t)(n + 1); }
        static inline uint8_t            ffxtest_inc_uint8(uint8_t n)            { return (uint8_t)(n + 1); }
        static inline int16_t            ffxtest_inc_int16(int16_t n)            { return (int16_t)(n + 1); }
        static inline uint16_t           ffxtest_inc_uint16(uint16_t n)          { return (uint16_t)(n + 1); }
        static inline int32_t            ffxtest_inc_int32(int32_t n)            { return n + 1; }
        static inline uint32_t           ffxtest_inc_uint32(uint32_t n)          { return n + 1; }
        static inline int64_t            ffxtest_inc_int64(int64_t n)            { return n + 1; }
        static inline uint64_t           ffxtest_inc_uint64(uint64_t n)          { return n + 1; }
        static inline long long          ffxtest_inc_ll(long long n)             { return n + 1; }
        static inline unsigned long long ffxtest_inc_ull(unsigned long long n)   { return n + 1; }
        static inline unsigned long      ffxtest_inc_ulong(unsigned long n)      { return n + 1; }
      C

      File.write(File.join(tmpdir, "mylib.rb"), <<~RUBY)
        require "ffi"

        module MyLib
          extend FFI::Library
          ffi_lib "c"

          attach_function :ffxtest_inc_short,  [:short],      :short
          attach_function :ffxtest_inc_ushort, [:ushort],     :ushort
          attach_function :ffxtest_inc_int8,   [:int8],       :int8
          attach_function :ffxtest_inc_uint8,  [:uint8],      :uint8
          attach_function :ffxtest_inc_int16,  [:int16],      :int16
          attach_function :ffxtest_inc_uint16, [:uint16],     :uint16
          attach_function :ffxtest_inc_int32,  [:int32],      :int32
          attach_function :ffxtest_inc_uint32, [:uint32],     :uint32
          attach_function :ffxtest_inc_int64,  [:int64],      :int64
          attach_function :ffxtest_inc_uint64, [:uint64],     :uint64
          attach_function :ffxtest_inc_ll,     [:long_long],  :long_long
          attach_function :ffxtest_inc_ull,    [:ulong_long], :ulong_long
          attach_function :ffxtest_inc_ulong,  [:ulong],      :ulong
        end
      RUBY

      File.write(File.join(tmpdir, "extconf.rb"), <<~RUBY)
        require "mkmf"
        $INCFLAGS << " -I" << __dir__
        require_relative "ffx"
        FFX.create_makefile("mylib", File.expand_path("mylib.rb", __dir__),
                            headers: ["ffxtest.h"])
      RUBY

      build_extension(tmpdir)

      ext_path = File.join(tmpdir, "mylib.#{DLEXT}")
      out = run_ruby(tmpdir, <<~RUBY)
        require "#{ext_path}"
        puts MyLib.ffxtest_inc_short(30_000)
        puts MyLib.ffxtest_inc_ushort(60_000)
        puts MyLib.ffxtest_inc_int8(100)
        puts MyLib.ffxtest_inc_uint8(250)
        puts MyLib.ffxtest_inc_int16(30_000)
        puts MyLib.ffxtest_inc_uint16(60_000)
        puts MyLib.ffxtest_inc_int32(2_000_000_000)
        puts MyLib.ffxtest_inc_uint32(4_000_000_000)
        puts MyLib.ffxtest_inc_int64(5_000_000_000_000)
        puts MyLib.ffxtest_inc_uint64(18_000_000_000_000_000_000)
        puts MyLib.ffxtest_inc_ll(5_000_000_000_000)
        puts MyLib.ffxtest_inc_ull(18_000_000_000_000_000_000)
        puts MyLib.ffxtest_inc_ulong(4_000_000_000)
      RUBY

      lines = out.lines.map(&:chomp)
      assert_equal "30001",                lines[0]
      assert_equal "60001",                lines[1]
      assert_equal "101",                  lines[2]
      assert_equal "251",                  lines[3]
      assert_equal "30001",                lines[4]
      assert_equal "60001",                lines[5]
      assert_equal "2000000001",           lines[6]
      assert_equal "4000000001",           lines[7]
      assert_equal "5000000000001",        lines[8]
      assert_equal "18000000000000000001", lines[9]
      assert_equal "5000000000001",        lines[10]
      assert_equal "18000000000000000001", lines[11]
      assert_equal "4000000001",           lines[12]
    end
  end

  private

  def build_extension(dir)
    Dir.chdir(dir) do
      assert system(RbConfig.ruby, "extconf.rb", out: File::NULL),
        "extconf.rb failed in #{dir}"
      assert system("make", out: File::NULL),
        "make failed in #{dir}"
    end
  end

  def run_ruby(dir, script)
    Dir.chdir(dir) do
      out = IO.popen([RbConfig.ruby, "-e", script], &:read)
      assert $?.success?, "ruby subprocess failed (#{$?}):\n#{out}"
      out
    end
  end
end
