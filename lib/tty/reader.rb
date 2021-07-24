# frozen_string_literal: true

require "tty-cursor"
require "tty-screen"
require "wisper"

require_relative "reader/completer"
require_relative "reader/history"
require_relative "reader/line"
require_relative "reader/key_event"
require_relative "reader/console"
require_relative "reader/win_console"
require_relative "reader/version"

module TTY
  # A class responsible for reading character input from STDIN
  #
  # Used internally to provide key and line reading functionality
  #
  # @api public
  class Reader
    include Wisper::Publisher

    # Key codes
    BACKSPACE = 8
    TAB       = 9
    NEWLINE   = 10
    CARRIAGE_RETURN = 13
    DELETE    = 127

    # Keys that terminate input
    EXIT_KEYS = %i[ctrl_d ctrl_z].freeze

    # Pattern to check if line ends with a line break character
    END_WITH_LINE_BREAK = /(\r|\n)$/.freeze

    # Raised when the user hits the interrupt key(Control-C)
    #
    # @api public
    InputInterrupt = Class.new(Interrupt)

    # Check if Windowz mode
    #
    # @return [Boolean]
    #
    # @api public
    def self.windows?
      ::File::ALT_SEPARATOR == "\\"
    end

    attr_reader :input

    attr_reader :output

    attr_reader :env

    attr_reader :track_history
    alias track_history? track_history

    # The handler for finding word completion suggestions
    #
    # @api public
    attr_reader :completion_handler

    # The suffix to add to suggested word completion
    #
    # @api public
    attr_reader :completion_suffix

    attr_reader :console

    attr_reader :cursor

    # Initialize a Reader
    #
    # @param [IO] input
    #   the input stream
    # @param [IO] output
    #   the output stream
    # @param [Symbol] interrupt
    #   the way to handle the Ctrl+C key out of :signal, :exit, :noop
    # @param [Hash] env
    #   the environment variables
    # @param [Boolean] track_history
    #   disable line history tracking, true by default
    # @param [Boolean] history_cycle
    #   allow cycling through history, false by default
    # @param [Boolean] history_duplicates
    #   allow duplicate entires, false by default
    # @param [Proc] history_exclude
    #   exclude lines from history, by default all lines are stored
    # @param [Proc] completion_handler
    #   the hanlder for finding word completion suggestions
    # @param [String] completion_suffix
    #   the suffix to add to suggested word completion
    #
    # @api public
    def initialize(input: $stdin, output: $stdout, interrupt: :error,
                   env: ENV, track_history: true, history_cycle: false,
                   history_exclude: History::DEFAULT_EXCLUDE,
                   history_size: History::DEFAULT_SIZE,
                   history_duplicates: false,
                   completion_handler: nil, completion_suffix: "")
      @input = input
      @output = output
      @interrupt = interrupt
      @env = env
      @track_history = track_history
      @history_cycle = history_cycle
      @history_exclude = history_exclude
      @history_duplicates = history_duplicates
      @history_size = history_size
      @completion_handler = completion_handler
      @completion_suffix = completion_suffix
      @completer = Completer.new(handler: completion_handler,
                                 suffix: completion_suffix)

      @console = select_console(input)
      @history = History.new(history_size) do |h|
        h.cycle = history_cycle
        h.duplicates = history_duplicates
        h.exclude = history_exclude
      end
      @cursor = TTY::Cursor
    end

    # Set completion handler
    #
    # @param [Proc] handler
    #   the handler for finding word completion suggestions
    #
    # @api public
    def completion_handler=(handler)
      @completion_handler = handler
      @completer.handler = handler
    end

    # Set completion suffix
    #
    # @param [String] suffix
    #   the suffix to add to suggested word completion
    #
    # @api public
    def completion_suffix=(suffix)
      @completion_suffix = suffix
      @completer.suffix = suffix
    end

    alias old_subcribe subscribe

    # Subscribe to receive key events
    #
    # @example
    #   reader.subscribe(MyListener.new)
    #
    # @return [self|yield]
    #
    # @api public
    def subscribe(listener, options = {})
      old_subcribe(listener, options)
      object = self
      if block_given?
        object = yield
        unsubscribe(listener)
      end
      object
    end

    # Unsubscribe from receiving key events
    #
    # @example
    #   reader.unsubscribe(my_listener)
    #
    # @return [void]
    #
    # @api public
    def unsubscribe(listener)
      registry = send(:local_registrations)
      registry.each do |object|
        if object.listener.equal?(listener)
          registry.delete(object)
        end
      end
    end

    # Select appropriate console
    #
    # @api private
    def select_console(input)
      if self.class.windows? && !env["TTY_TEST"]
        WinConsole.new(input)
      else
        Console.new(input)
      end
    end

    # Get input in unbuffered mode.
    #
    # @example
    #   unbufferred do
    #     ...
    #   end
    #
    # @api public
    def unbufferred(&block)
      bufferring = output.sync
      # Immediately flush output
      output.sync = true
      block[] if block_given?
    ensure
      output.sync = bufferring
    end

    # Read a keypress including invisible multibyte codes and return
    # a character as a string.
    # Nothing is echoed to the console. This call will block for a
    # single keypress, but will not wait for Enter to be pressed.
    #
    # @param [Boolean] echo
    #   whether to echo chars back or not, defaults to false
    # @option [Boolean] raw
    #   whenther raw mode is enabled, defaults to true
    # @option [Boolean] nonblock
    #   whether to wait for input or not, defaults to false
    #
    # @return [String]
    #
    # @api public
    def read_keypress(echo: false, raw: true, nonblock: false)
      codes = unbufferred do
        get_codes(echo: echo, raw: raw, nonblock: nonblock)
      end
      char = codes ? codes.pack("U*") : nil

      trigger_key_event(char) if char
      char
    end
    alias read_char read_keypress

    # Get input code points
    #
    # @param [Boolean] echo
    #   whether to echo chars back or not, defaults to false
    # @option [Boolean] raw
    #   whenther raw mode is enabled, defaults to true
    # @option [Boolean] nonblock
    #   whether to wait for input or not, defaults to false
    # @param [Array[Integer]] codes
    #   the currently read char code points
    #
    # @return [Array[Integer]]
    #
    # @api private
    def get_codes(echo: true, raw: false, nonblock: false, codes: [])
      char = console.get_char(echo: echo, raw: raw, nonblock: nonblock)
      handle_interrupt if console.keys[char] == :ctrl_c
      return if char.nil?

      codes << char.ord
      condition = proc { |escape|
        (codes - escape).empty? ||
        (escape - codes).empty? &&
        !(64..126).cover?(codes.last)
      }

      while console.escape_codes.any?(&condition)
        char_codes = get_codes(echo: echo, raw: raw,
                               nonblock: true, codes: codes)
        break if char_codes.nil?
      end

      codes
    end

    # Get a single line from STDIN. Each key pressed is echoed
    # back to the shell. The input terminates when enter or
    # return key is pressed.
    #
    # @param [String] prompt
    #   the prompt to display before input
    # @param [String] value
    #   the value to pre-populate line with
    # @param [Boolean] echo
    #   whether to echo chars back or not, defaults to false
    # @param [Array<Symbol>] exit_keys
    #   the custom keys to exit line editing
    # @option [Boolean] raw
    #   whenther raw mode is enabled, defaults to true
    # @option [Boolean] nonblock
    #   whether to wait for input or not, defaults to false
    #
    # @return [String]
    #
    # @api public
    def read_line(prompt = "", value: "", echo: true, raw: true,
                  nonblock: false, exit_keys: nil)
      line = Line.new(value, prompt: prompt)
      screen_width = TTY::Screen.width
      history_in_use = false
      previous_key_name = ""
      buffer = ""

      output.print(line)

      while (codes = get_codes(echo: echo, raw: raw, nonblock: nonblock)) &&
            (code = codes[0])
        char = codes.pack("U*")
        key_name = console.keys[char]

        if exit_keys && exit_keys.include?(key_name)
          trigger_key_event(char, line: line.to_s)
          break
        end

        if raw && echo
          clear_display(line, screen_width)
        end

        if (key_name == :tab || code == TAB || key_name == :shift_tab) &&
           completion_handler
          initial = previous_key_name != :tab && previous_key_name != :shift_tab
          direction = key_name == :shift_tab ? :previous : :next
          @completer.complete(line, initial: initial, direction: direction)
        elsif key_name == :backspace || code == BACKSPACE
          if !line.start?
            line.left
            line.delete
          end
        elsif key_name == :delete || code == DELETE
          line.delete
        elsif key_name.to_s =~ /ctrl_/
          # skip
        elsif key_name == :up
          @history.replace(line.text) if history_in_use
          if history_previous?
            line.replace(history_previous(skip: !history_in_use))
            history_in_use = true
          end
        elsif key_name == :down
          @history.replace(line.text) if history_in_use
          if history_next?
            line.replace(history_next)
          elsif history_in_use
            line.replace(buffer)
            history_in_use = false
          end
        elsif key_name == :left
          line.left
        elsif key_name == :right
          line.right
        elsif key_name == :home
          line.move_to_start
        elsif key_name == :end
          line.move_to_end
        else
          if raw && [CARRIAGE_RETURN, NEWLINE].include?(code)
            char = "\n"
            line.move_to_end
          end
          line.insert(char)
          buffer = line.text unless history_in_use
        end

        if (key_name == :backspace || code == BACKSPACE) && echo
          if raw
            output.print("\e[1X") unless line.start?
          else
            output.print(?\s + (line.start? ? "" : ?\b))
          end
        end

        previous_key_name = key_name

        # trigger before line is printed to allow for line changes
        trigger_key_event(char, line: line.to_s)

        if raw && echo
          output.print(line.to_s)
          if char == "\n"
            line.move_to_start
          elsif !line.end? # readjust cursor position
            output.print(cursor.backward(line.text_size - line.cursor))
          end
        end

        if [CARRIAGE_RETURN, NEWLINE].include?(code)
          buffer = ""
          output.puts unless echo
          break
        end
      end

      if track_history? && echo
        add_to_history(line.text.rstrip)
      end

      line.text
    end

    # Clear display for the current line input
    #
    # Handles clearing input that is longer than the current
    # terminal width which allows copy & pasting long strings.
    #
    # @param [Line] line
    #   the line to display
    # @param [Number] screen_width
    #   the terminal screen width
    #
    # @api private
    def clear_display(line, screen_width)
      total_lines  = count_screen_lines(line.size, screen_width)
      current_line = count_screen_lines(line.prompt_size + line.cursor, screen_width)
      lines_down = total_lines - current_line

      output.print(cursor.down(lines_down)) unless lines_down.zero?
      output.print(cursor.clear_lines(total_lines))
    end

    # Count the number of screen lines given line takes up in terminal
    #
    # @param [Integer] line_or_size
    #   the current line or its length
    # @param [Integer] screen_width
    #   the width of terminal screen
    #
    # @return [Integer]
    #
    # @api public
    def count_screen_lines(line_or_size, screen_width = TTY::Screen.width)
      line_size = if line_or_size.is_a?(Integer)
                    line_or_size
                  else
                    Line.sanitize(line_or_size).size
                  end
      # new character + we don't want to add new line on screen_width
      new_chars = self.class.windows? ? -1 : 1
      1 + [0, (line_size - new_chars) / screen_width].max
    end

    # Read multiple lines and return them in an array.
    # Skip empty lines in the returned lines array.
    # The input gathering is terminated by Ctrl+d or Ctrl+z.
    #
    # @param [String] prompt
    #   the prompt displayed before the input
    # @param [String] value
    #   the value to pre-populate line with
    # @param [Boolean] echo
    #   whether to echo chars back or not, defaults to false
    # @param [Array<Symbol>] exit_keys
    #   the custom keys to exit line editing
    # @option [Boolean] raw
    #   whenther raw mode is enabled, defaults to true
    # @option [Boolean] nonblock
    #   whether to wait for input or not, defaults to false
    #
    # @yield [String] line
    #
    # @return [Array[String]]
    #
    # @api public
    def read_multiline(prompt = "", value: "", echo: true, raw: true,
                       nonblock: false, exit_keys: EXIT_KEYS)
      lines = []
      stop = false
      clear_value = !value.to_s.empty?

      loop do
        line = read_line(prompt, value: value, echo: echo, raw: raw,
                                 nonblock: nonblock, exit_keys: exit_keys).to_s
        if clear_value
          clear_value = false
          value = ""
        end
        break if line.empty?

        stop = line.match(END_WITH_LINE_BREAK).nil?
        next if line !~ /\S/ && !stop

        if block_given?
          yield(line)
        else
          lines << line
        end
        break if stop
      end

      lines
    end
    alias read_lines read_multiline

    # Expose event broadcasting
    #
    # @api public
    def trigger(event, *args)
      publish(event, *args)
    end

    # Add a line to history
    #
    # @param [String] line
    #
    # @api private
    def add_to_history(line)
      @history.push(line)
    end

    # Check if history has next line
    #
    # @param [Boolean]
    #
    # @api private
    def history_next?
      @history.next?
    end

    # Move history to the next line
    #
    # @return [String]
    #   the next line
    #
    # @api private
    def history_next
      @history.next
      @history.get
    end

    # Check if history has previous line
    #
    # @return [Boolean]
    #
    # @api private
    def history_previous?
      @history.previous?
    end

    # Move history to the previous line
    #
    # @param [Boolean] skip
    #   whether or not to move history index
    #
    # @return [String]
    #   the previous line
    #
    # @api private
    def history_previous(skip: false)
      @history.previous unless skip
      @history.get
    end

    # Inspect class name and public attributes
    #
    # @return [String]
    #
    # @api public
    def inspect
      "#<#{self.class}: @input=#{input}, @output=#{output}>"
    end

    private

    # Publish event
    #
    # @param [String] char
    #   the key pressed
    #
    # @return [nil]
    #
    # @api private
    def trigger_key_event(char, line: "")
      event = KeyEvent.from(console.keys, char, line)
      trigger(:"key#{event.key.name}", event) if event.trigger?
      trigger(:keypress, event)
    end

    # Handle input interrupt based on provided value
    #
    # @api private
    def handle_interrupt
      case @interrupt
      when :signal
        Process.kill("SIGINT", Process.pid)
      when :exit
        exit(130)
      when Proc
        @interrupt.call
      when :noop
        # Noop
      else
        raise InputInterrupt
      end
    end
  end # Reader
end # TTY
