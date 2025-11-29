# frozen_string_literal: true

require "strscan"

module Yaic
  class Message
    attr_reader :tags, :source, :command, :params, :raw

    def initialize(tags: {}, source: nil, command: nil, params: [])
      @tags = tags
      @source = source
      @command = command
      @params = params
      @raw = nil
    end

    def self.parse(str)
      return nil if str.nil? || str.empty?

      str = str.b.force_encoding("UTF-8")
      str = str.encode("UTF-8", "ISO-8859-1", invalid: :replace, undef: :replace) unless str.valid_encoding?

      stripped = str.chomp("\r\n").chomp("\n")
      return nil if stripped.empty?

      scanner = StringScanner.new(stripped)

      tags = parse_tags(scanner)
      source = parse_source(scanner)
      command = parse_command(scanner)
      params = parse_params(scanner)

      msg = new(tags: tags, source: source, command: command, params: params)
      msg.instance_variable_set(:@raw, str)
      msg
    end

    def to_s
      parts = []
      parts << @command

      @params.each_with_index do |param, idx|
        is_last = idx == @params.length - 1
        parts << if is_last && needs_trailing_prefix?(param)
          ":#{param}"
        else
          param
        end
      end

      "#{parts.join(" ")}\r\n"
    end

    private

    def needs_trailing_prefix?(param)
      param.empty? || param.include?(" ") || param.start_with?(":")
    end

    class << self
      private

      def parse_tags(scanner)
        tags = {}

        if scanner.peek(1) == "@"
          scanner.getch
          tag_str = scanner.scan(/[^ ]+/)
          skip_spaces(scanner)

          tag_str&.split(";")&.each do |tag|
            key, value = tag.split("=", 2)
            tags[key] = value || ""
          end
        end

        tags
      end

      def parse_source(scanner)
        return nil unless scanner.peek(1) == ":"

        scanner.getch
        source_str = scanner.scan(/[^ ]+/)
        skip_spaces(scanner)

        Source.parse(source_str)
      end

      def parse_command(scanner)
        cmd = scanner.scan(/[A-Za-z]+|\d{3}/)
        skip_spaces(scanner)
        cmd
      end

      def parse_params(scanner)
        params = []

        until scanner.eos?
          if scanner.peek(1) == ":"
            scanner.getch
            params << scanner.rest
            break
          else
            param = scanner.scan(/[^ ]+/)
            params << param if param
            skip_spaces(scanner)
          end
        end

        params
      end

      def skip_spaces(scanner)
        scanner.skip(/ +/)
      end
    end
  end
end
