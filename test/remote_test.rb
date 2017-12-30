require 'test_helper'

module Byebug
  #
  # Tests remote debugging functionality.
  #
  class RemoteTest < TestCase
    def program
      strip_line_numbers <<-RUBY
         1:  module Byebug
         2:    #
         3:    # Toy class to test remote debugging
         4:    #
         5:    class #{example_class}
         6:      def a
         7:        3
         8:      end
         9:    end
        10:
        11:    self.wait_connection = true
        12:    self.start_server
        13:
        14:    byebug
        15:
        16:    #{example_class}.new.a
        17:  end
      RUBY
    end

    def test_connecting_to_the_remote_debugger
      enter 'quit!'

      remote_debug(program)

      check_output_includes 'Connecting to byebug server...', 'Connected.'
    end

    def test_interacting_with_the_remote_debugger
      enter 'cont 7', 'cont'

      remote_debug(program)

      check_output_includes \
        '5:   class ByebugTestClass',
        '6:     def a',
        '=>  7:       3',
        '8:     end'
    end

    private

    def remote_debug(program)
      # spawn server
      pid = fork { debug_in_temp_file(program) }

      launch_client

      # Wait for server termination
      Process.wait(pid)
    end

    def launch_client
      Byebug::Remote::Client.new(interface).start
    rescue Errno::ECONNREFUSED
      sleep 0.1 && retry
    end
  end
end
