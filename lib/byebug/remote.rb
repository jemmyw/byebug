require 'socket'
require 'byebug/processors/control_processor'

#
# Remote debugging functionality.
#
# @todo Refactor & add tests
#
module Byebug
  # Port number used for remote debugging
  PORT = 8989 unless defined?(PORT)

  class << self
    # If in remote mode, wait for the remote connection
    attr_accessor :wait_connection

    # The actual port that the server is started at
    attr_accessor :actual_port
    attr_reader :actual_control_port

    #
    # Interrupts the current thread
    #
    def interrupt
      current_context.interrupt
    end

    #
    # Starts a remote byebug
    #
    def start_server(host = nil, port = PORT)
      return if @thread

      Context.interface = nil
      start

      start_control(host, port.zero? ? 0 : port + 1)

      mutex = Mutex.new
      proceed = ConditionVariable.new

      server = TCPServer.new(host, port)
      self.actual_port = server.addr[1]

      yield if block_given?

      @thread = DebugThread.new do
        while (session = server.accept)
          Context.interface = RemoteInterface.new(session)
          mutex.synchronize { proceed.signal } if wait_connection
        end
      end

      mutex.synchronize { proceed.wait(mutex) } if wait_connection
    end

    def start_control(host = nil, ctrl_port = PORT + 1)
      return @actual_control_port if @control_thread
      server = TCPServer.new(host, ctrl_port)
      @actual_control_port = server.addr[1]

      @control_thread = DebugThread.new do
        while (session = server.accept)
          Context.interface = RemoteInterface.new(session)

          ControlProcessor.new(Byebug.current_context).process_commands
        end
      end

      @actual_control_port
    end

    #
    # Connects to the remote byebug
    #
    def start_client(host = 'localhost', port = PORT)
      interface = LocalInterface.new
      puts 'Connecting to byebug server...'
      socket = TCPSocket.new(host, port)
      puts 'Connected.'

      while (line = socket.gets)
        case line
        when /^PROMPT (.*)$/
          input = interface.read_command(Regexp.last_match[1])
          break unless input
          socket.puts input
        when /^CONFIRM (.*)$/
          input = interface.readline(Regexp.last_match[1])
          break unless input
          socket.puts input
        else
          puts line
        end
      end

      socket.close
    end

    def start_client_control(host = nil, port = PORT)
      puts 'Connecting to byebug'
      socket = TCPSocket.new(host, port)
      conn_line = socket.gets
      unless conn_line =~ /CONN (\d+)$/
        puts "Invalid connection"
        socket.close
      else
        puts "Connected #{Regexp.last_match[1]}"
        Context.interface = RemoteInterface.new(socket)
      end
    end

    def start_server_interface(host = nil, port = PORT)
      puts 'Starting server'
      server = TCPServer.new(host, port)
      count = 0
      interface = LocalInterface.new
      connections = {}
      current_connection = nil

      count_mutex = Mutex.new

      @thread = Thread.new do
        while socket = server.accept
          count_mutex.synchronize do
            count += 1
            connections[count] = socket
            current_connection = count if current_connection.nil?
            socket.puts "CONN #{count}"
          end
        end
      end

      interface = LocalInterface.new

      loop do
        if current_connection
          this_connection = current_connection
          socket = connections[current_connection]

          while (line = socket.gets)
            case line
            when /^PROMPT (.*)$/
              begin
                input = interface.read_command("#{conn}: #{Regexp.last_match[1]}")
                break unless input
                if input =~ /i (\d+)$/
                  conn = Regexp.last_match[1].to_i
                  if connections[conn]
                    current_connection = Regexp.last_match[i].to_i
                    break
                  else
                    puts "No connection #{conn}"
                    throw 'no connection'
                  end
                end
              rescue
                retry
              end
              socket.puts input
            when /^CONFIRM (.*)$/
              input = interface.readline("#{conn}: #{Regexp.last_match[1]}")
              break unless input
              socket.puts input
            else
              puts line
            end
          end

          if current_connection == this_connection
            connections[current_connection] = nil
            current_connection = nil
          end
        else
          input = interface.read_command('connection? ')
          if input.to_i > 0 && connections[input.to_i]
            current_connection = input.to_i
          end
        end
      end
    end

    def parse_host_and_port(host_port_spec)
      location = host_port_spec.split(':')
      location[1] ? [location[0], location[1].to_i] : ['localhost', location[0]]
    end
  end
end
