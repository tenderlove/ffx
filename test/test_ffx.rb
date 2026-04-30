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
