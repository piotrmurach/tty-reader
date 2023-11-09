# frozen_string_literal: true

require "forwardable"

module TTY
  class Reader
    class Line
      ANSI_MATCHER = /(\[)?\033(\[)?[;?\d]*[\dA-Za-z](\])?/

      # The word break characters list used by shell
      DEFAULT_WORD_BREAK_CHARACTERS = " \t\n\"\\'`@$><=|&{("

      # Strip ANSI characters from the text
      #
      # @param [String] text
      #
      # @return [String]
      #
      # @api public
      def self.sanitize(text)
        text.dup.gsub(ANSI_MATCHER, "")
      end

      # The editable text
      # @api public
      attr_reader :text

      # The current cursor position witin the text
      # @api public
      attr_reader :cursor

      # The line mode
      # @api public
      attr_reader :mode

      # The prompt displayed before input
      # @api public
      attr_reader :prompt

      # The prompt size
      # @api public
      attr_reader :prompt_size

      # The word separator pattern for splitting the text
      #
      # @return [Regexp]
      #
      # @api public
      attr_reader :separator

      # Create a Line instance
      #
      # @api private
      def initialize(text = "", prompt: "", separator: nil)
        @text   = text.dup
        @prompt = prompt.dup
        @prompt_size = prompt_display_width
        break_chars = DEFAULT_WORD_BREAK_CHARACTERS.chars
        @separator = separator || Regexp.union(break_chars)
        @cursor = [0, @text.length].max
        @mode   = :edit

        yield self if block_given?
      end

      # Prompt display width
      #
      # @return [Integer]
      #   the prompt size
      #
      # @api public
      def prompt_display_width
        lines = self.class.sanitize(@prompt).split(/\r?\n/)
        return 0 if lines.empty?

        # return the length of each line + screen width for every line
        # past the first which accounts for multi-line prompts
        lines.join.length + ((lines.length - 1) * TTY::Screen.width)
      end

      # Check if line is in edit mode
      #
      # @return [Boolean]
      #
      # @public
      def editing?
        @mode == :edit
      end

      # Enable edit mode
      #
      # @return [Boolean]
      #
      # @public
      def edit_mode
        @mode = :edit
      end

      # Check if line is in replace mode
      #
      # @return [Boolean]
      #
      # @public
      def replacing?
        @mode == :replace
      end

      # Enable replace mode
      #
      # @return [Boolean]
      #
      # @public
      def replace_mode
        @mode = :replace
      end

      # Check if cursor reached beginning of the line
      #
      # @return [Boolean]
      #
      # @api public
      def start?
        @cursor.zero?
      end

      # Check if cursor reached end of the line
      #
      # @return [Boolean]
      #
      # @api public
      def end?
        @cursor == @text.length
      end

      # Move line position to the left by n chars
      #
      # @api public
      def left(n = 1)
        @cursor = [0, @cursor - n].max
      end

      # Move line position to the right by n chars
      #
      # @api public
      def right(n = 1)
        @cursor = [@text.length, @cursor + n].min
      end

      # Move cursor to beginning position
      #
      # @api public
      def move_to_start
        @cursor = 0
      end

      # Move cursor to end position
      #
      # @api public
      def move_to_end
        @cursor = @text.length # put cursor outside of text
      end

      # Insert characters inside a line. When the lines exceeds
      # maximum length, an extra space is added to accomodate index.
      #
      # @param [Integer] i
      #   the index to insert at
      #
      # @param [String] chars
      #   the characters to insert
      #
      # @example
      #   text = "aaa"
      #   line[5]= "b"
      #   => "aaa  b"
      #
      # @api public
      def []=(i, chars)
        edit_mode

        if i.is_a?(Range)
          @text[i] = chars
          @cursor += chars.length
          return
        end

        if i <= 0
          before_text = ""
          after_text = @text.dup
        elsif i > @text.length - 1 # insert outside of line input
          before_text = @text.dup
          after_text = ?\s * (i - @text.length)
          @cursor += after_text.length
        else
          before_text = @text[0..i-1].dup
          after_text  = @text[i..-1].dup
        end

        if i > @text.length - 1
          @text = before_text + after_text + chars
        else
          @text = before_text + chars + after_text
        end

        @cursor = i + chars.length
      end

      # Read character
      #
      # @api public
      def [](i)
        @text[i]
      end

      # Find a word under the cursor based on a separator
      #
      # @param [Boolean] before
      #   whether to start searching before or after a break character
      #
      # @return [String]
      #
      # @api public
      def word(before: true)
        start_pos = word_start_pos(before: before)
        @text[start_pos..word_end_pos(from: start_pos)]
      end

      # Find a word up to a cursor position
      #
      # @param [Boolean] before
      #   whether to start searching before or after a break character
      #
      # @return [String]
      #
      # @api public
      def word_to_complete(before: true)
        @text[word_start_pos(before: before)...@cursor]
      end

      # Find word start position
      #
      # @param [Integer] from
      #   the index to start searching from, defaults to cursor position
      #
      # @param [Symbol] before
      #   whether to start search before or after break character
      #
      # @return [Integer]
      #
      # @api public
      def word_start_pos(from: @cursor, before: true)
        # move back or forward by one character when at a word boundary
        if word_boundary?
          from = before ? from - 1 : from + 1
        end

        start_pos = @text.rindex(separator, from) || 0
        start_pos += 1 unless start_pos.zero?
        start_pos
      end

      # Find word end position
      #
      # @param [Integer] from
      #   the index to start searching from, defaults to cursor position
      #
      # @return [Integer]
      #
      # @api public
      def word_end_pos(from: @cursor)
        end_pos = @text.index(separator, from) || text_size
        end_pos -= 1 unless @text.empty?
        end_pos
      end

      # Check if cursor is at a word boundary
      #
      # @return [Boolean]
      #
      # @api private
      def word_boundary?
        @text[@cursor] =~ separator
      end

      # Replace current line with new text
      #
      # @param [String] text
      #
      # @api public
      def replace(text)
        @text = text
        @cursor = @text.length # put cursor outside of text
        replace_mode
      end

      # Insert char(s) at cursor position
      #
      # @api public
      def insert(chars)
        self[@cursor] = chars
      end

      # Add char and move cursor
      #
      # @api public
      def <<(str)
        @text << str
        @cursor += str.length
      end

      # Remove char from the line at current position
      #
      # @api public
      def delete(n = 1)
        @text.slice!(@cursor, n)
      end

      # Remove char from the line in front of the cursor
      #
      # @param [Integer] n
      #   the number of chars to remove
      #
      # @api public
      def remove(n = 1)
        left(n)
        @text.slice!(@cursor, n)
      end

      # Full line with prompt as string
      #
      # @api public
      def to_s
        "#{@prompt}#{@text}"
      end

      # to_str enables type coercion and thus `line` in
      # `trigger_char_event` does not need to be flattened to a string.
      alias to_str to_s

      # Overload inspect
      #
      # @api public
      def inspect
        to_s.inspect
      end

      # Overload equality comparison
      #
      # @api public
      def ==(other)
        if other.is_a? self.class
          super other
        else
          other = other.to_s if other.respond_to? :to_s
          to_s == other
        end
      end

      # Text size
      #
      # @api public
      def text_size
        self.class.sanitize(@text).size
      end

      # Full line size with prompt
      #
      # @api public
      def size
        prompt_size + text_size
      end
      alias length size
    end # Line
  end # Reader
end # TTY
