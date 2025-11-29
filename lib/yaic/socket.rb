# frozen_string_literal: true

require "socket"
require "openssl"

module Yaic
  class Socket
    attr_reader :state

    def initialize(host, port, ssl: false, verify_mode: nil, connect_timeout: 30)
      @host = host
      @port = port
      @ssl = ssl
      @verify_mode = verify_mode || OpenSSL::SSL::VERIFY_NONE
      @connect_timeout = connect_timeout

      @socket = nil
      @read_buffer = String.new(encoding: Encoding::ASCII_8BIT)
      @write_queue = []
      @state = :disconnected
    end

    def connect
      addrinfo = resolve_address
      tcp_socket = ::Socket.new(addrinfo.afamily, ::Socket::SOCK_STREAM)
      tcp_socket.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE, true)

      begin
        tcp_socket.connect_nonblock(addrinfo)
      rescue IO::WaitWritable
        if IO.select(nil, [tcp_socket], nil, @connect_timeout)
          begin
            tcp_socket.connect_nonblock(addrinfo)
          rescue Errno::EISCONN
          end
        else
          tcp_socket.close
          raise Errno::ETIMEDOUT, "Connection timed out"
        end
      end

      @socket = if @ssl
        wrap_ssl(tcp_socket)
      else
        tcp_socket
      end

      @state = :connecting
    end

    def disconnect
      return if @state == :disconnected

      begin
        @socket&.close
      rescue
        nil
      end
      @socket = nil
      @read_buffer.clear
      @write_queue.clear
      @state = :disconnected
    end

    def read
      return nil if @socket.nil?

      begin
        data = @socket.read_nonblock(4096)
        buffer_data(data)
        extract_message
      rescue IO::WaitReadable
        extract_message
      rescue IOError, Errno::ECONNRESET
        nil
      end
    end

    def write(message)
      return if @socket.nil?

      message = message.dup
      message << "\r\n" unless message.end_with?("\r\n", "\n")

      begin
        @socket.write_nonblock(message)
      rescue IO::WaitWritable
        @write_queue << message
        flush_write_queue
      end
    end

    private

    def resolve_address
      addrs = Addrinfo.getaddrinfo(@host, @port, nil, :STREAM)
      ipv4 = addrs.find { |a| a.afamily == ::Socket::AF_INET }
      ipv4 || addrs.first
    end

    def wrap_ssl(tcp_socket)
      context = OpenSSL::SSL::SSLContext.new
      context.verify_mode = @verify_mode

      ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, context)
      ssl_socket.hostname = @host
      ssl_socket.sync = true
      ssl_socket.connect
      ssl_socket
    end

    def buffer_data(data)
      @read_buffer << data
    end

    def extract_message
      if (idx = @read_buffer.index("\n"))
        @read_buffer.slice!(0..idx)
      end
    end

    def flush_write_queue
      while @write_queue.any?
        begin
          @socket.write_nonblock(@write_queue.first)
          @write_queue.shift
        rescue IO::WaitWritable
          break
        end
      end
    end
  end
end
