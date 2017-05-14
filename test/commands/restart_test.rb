require 'test_helper'
require 'rbconfig'
require 'byebug/helpers/string'

module Byebug
  #
  # Tests restarting functionality.
  #
  class RestartTest < TestCase
    include Helpers::StringHelper

    def setup
      super

      example_file.write(program)
      example_file.close
    end

    def program
      deindent <<-'RUBY', leading_spaces: 8
        #!/usr/bin/env ruby

        require 'English'
        require 'byebug'

        byebug

        if $ARGV.empty?
          print "Run program #{$PROGRAM_NAME} with no args"
        else
          print "Run program #{$PROGRAM_NAME} with args #{$ARGV.join(',')}"
        end
      RUBY
    end

    def test_restart_with_no_args__original_script_with_no_args__standalone
      skip if windows?

      assert_restarts(
        "#{byebug_bin} #{example_path}",
        'restart',
        "Run program #{example_path} with no args"
      )
    end

    def test_restart_with_no_args__original_script_with_no_args__attached
      skip if windows?

      assert_restarts(
        example_path,
        'restart',
        "Run program #{example_path} with no args"
      )
    end

    def test_restart_with_no_args__original_script_through_ruby__attached
      assert_restarts(
        "#{ruby_bin} #{example_path}",
        'restart',
        "Run program #{example_path} with no args"
      )
    end

    def test_restart_with_no_args__standalone
      skip if windows?

      assert_restarts(
        "#{byebug_bin} #{example_path} 1",
        'restart',
        "Run program #{example_path} with args 1"
      )
    end

    def test_restart_with_args__standalone
      skip if windows?

      assert_restarts(
        "#{byebug_bin} #{example_path} 1",
        'restart 2',
        "Run program #{example_path} with args 2"
      )
    end

    def test_restart_with_no_args__attached
      assert_restarts(
        "#{example_path} 1",
        'restart',
        "Run program #{example_path} with args 1"
      )
    end

    def test_restart_with_args__attached
      assert_restarts(
        "#{example_path} 1",
        'restart 2',
        "Run program #{example_path} with args 2"
      )
    end

    private

    def assert_restarts(launch_command, restart_command, expected_message)
      stdout = run_program(launch_command, restart_command)

      assert_match(/#{expected_message}/, stdout)
    end

    def ruby_bin
      RbConfig.ruby
    end

    def byebug_bin
      Context.bin_file
    end
  end
end
