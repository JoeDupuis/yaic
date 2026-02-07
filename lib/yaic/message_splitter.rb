# frozen_string_literal: true

module Yaic
  module MessageSplitter
    module_function

    def max_text_bytes(line_length:, command:, target:, prefix_length: 0)
      overhead = command.bytesize + 1 + target.bytesize + 2 + 2 + prefix_length
      result = line_length - overhead
      [result, 1].max
    end

    def split(text, max_bytes:)
      text = text.to_s
      return [text] if text.bytesize <= max_bytes

      chunks = []
      remaining = text.dup
      while remaining.bytesize > 0
        chunk = safe_truncate(remaining, max_bytes)
        break if chunk.empty?
        chunks << chunk
        remaining = remaining[chunk.length..]
      end
      chunks
    end

    def safe_truncate(text, max_bytes)
      return text if text.bytesize <= max_bytes
      truncated = text.byteslice(0, max_bytes)
      while truncated.bytesize > 0 && !truncated.valid_encoding?
        truncated = truncated.byteslice(0, truncated.bytesize - 1)
      end
      truncated
    end
  end
end
