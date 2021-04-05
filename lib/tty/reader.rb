# frozen_string_literal: true

require "tty-cursor"
require "tty-screen"
require "wisper"

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
    CARRIAGE_RETURN = 13
    NEWLINE         = 10
    BACKSPACE       = 8
    DELETE          = 127

    # Keys that terminate input
    EXIT_KEYS = [:ctrl_d, :ctrl_z]

    #Provide with a dummy lambda to arrange sugestions for auto completion
    COMPLETION = ->(text) { [] }

    #Provide with a basic lambda to display completion matches
    DISPLAY_COMPLETION_MATCHES = ->(completions, line, echo: true) {
        completions.each { |completion| puts "#{completion}\n"} if echo
    }

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

    attr_accessor :completion

    attr_reader :completion_key

    attr_accessor :completion_proc

    attr_accessor :display_completion_matches_proc

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
    # @param [Boolean] completion
    #   enable auto completion, false by default
    # @param [Symbol] completion_key
    #   defines the key that triggers auto completion
    # @param [Proc] completion_proc
    #   arrange suggestions for auto completion
    # @param [Proc] display_completion_matches_proc
    #   display candidates for auto completion
    #
    # @api public
    def initialize(input: $stdin, output: $stdout, interrupt: :error,
                   env: ENV, track_history: true, history_cycle: false,
                   history_exclude: History::DEFAULT_EXCLUDE,
                   history_size: History::DEFAULT_SIZE,
                   history_duplicates: false,
                   completion: false, completion_key: :tab, completion_proc: COMPLETION,
                   display_completion_matches_proc: DISPLAY_COMPLETION_MATCHES )
      @input = input
      @output = output
      @interrupt = interrupt
      @env = env
      @track_history = track_history
      @history_cycle = history_cycle
      @history_exclude = history_exclude
      @history_duplicates = history_duplicates
      @history_size = history_size
      @completion = completion
      @completion_key = completion_key
      @completion_proc = completion_proc
      @display_completion_matches_proc = display_completion_matches_proc

      @console = select_console(input)
      @history = History.new(history_size) do |h|
        h.cycle = history_cycle
        h.duplicates = history_duplicates
        h.exclude = history_exclude
      end
      @stop = false # gathering input
      @cursor = TTY::Cursor

      subscribe(self)
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

    # Complete word according to suggestions
    #
    # @api private
    def complete_word(line, echo: true)
      text = line.text
      (text.empty? || text[-1] =~ /\s/) ? word = "" : word = text.split.last
      suggestions = completion_proc.call(text)
      completions = suggestions.grep(/^#{Regexp.escape(word)}/)
      position = word.length
      if completions.size > 1
        char = completions.first[position]
        if completions.all? { |completion| completion[position] == char }
          line.insert(char)
          complete_word(line, echo: echo)
        else
          display_completion_matches_proc.call(completions, line, echo: echo)
        end
      elsif completions.size == 1
        line.insert(completions.first[position..-1])
        line.insert("\s")
      end
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
    # @option [Boolean] raw
    #   whenther raw mode is enabled, defaults to true
    # @option [Boolean] nonblock
    #   whether to wait for input or not, defaults to false
    #
    # @return [String]
    #
    # @api public
    def read_line(prompt = "", value: "", echo: true, raw: true, nonblock: false)
      line = Line.new(value, prompt: prompt)
      screen_width = TTY::Screen.width
      buffer = ""

      output.print(line)

      while (codes = get_codes(echo: echo, raw: raw, nonblock: nonblock)) &&
            (code = codes[0])
        char = codes.pack("U*")

        if EXIT_KEYS.include?(console.keys[char])
          trigger_key_event(char, line: line.to_s)
          break
        end

        if raw && echo
          clear_display(line, screen_width)
        end

        if console.keys[char] == :backspace || code == BACKSPACE
          if !line.start?
            line.left
            line.delete
          end
        elsif console.keys[char] == :delete || code == DELETE
          line.delete
        elsif console.keys[char].to_s =~ /ctrl_/
          # skip
        elsif console.keys[char] == :up
          line.replace(history_previous) if history_previous?
        elsif console.keys[char] == :down
          line.replace(history_next? ? history_next : buffer) if track_history?
        elsif console.keys[char] == :left
          line.left
        elsif console.keys[char] == :right
          line.right
        elsif console.keys[char] == :home
          line.move_to_start
        elsif console.keys[char] == :end
          line.move_to_end
        elsif console.keys[char] == completion_key && completion == true
          complete_word(line, echo: echo)
        else
          if raw && [CARRIAGE_RETURN, NEWLINE].include?(code)
            char = "\n"
            line.move_to_end
          end
          line.insert(char)
          buffer = line.text
        end

        if (console.keys[char] == :backspace || code == BACKSPACE) && echo
          if raw
            output.print("\e[1X") unless line.start?
          else
            output.print(?\s + (line.start? ? "" : ?\b))
          end
        end

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
                       nonblock: false)
      @stop = false
      lines = []
      empty_str = ""

      loop do
        line = read_line(prompt, value: value, echo: echo, raw: raw,
                                 nonblock: nonblock)
        value = empty_str unless value.empty? # reset
        break if !line || line == empty_str
        next  if line !~ /\S/ && !@stop

        if block_given?
          yield(line) unless line.to_s.empty?
        else
          lines << line unless line.to_s.empty?
        end
        break if @stop
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

    # Capture Ctrl+d and Ctrl+z key events
    #
    # @api private
    def keyctrl_d(*)
      @stop = true
    end
    alias keyctrl_z keyctrl_d

    def add_to_history(line)
      @history.push(line)
    end

    def history_next?
      @history.next?
    end

    def history_next
      @history.next
      @history.get
    end

    def history_previous?
      @history.previous?
    end

    def history_previous
      line = @history.get
      @history.previous
      line
    end

    # Inspect class name and public attributes
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
