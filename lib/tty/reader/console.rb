# frozen_string_literal: true

require "io/wait"

require_relative "keys"
require_relative "mode"

module TTY
  class Reader
    class Console
      ESC = "\e"
      CSI = "\e["
      XTERM = "\eO"

      TIMEOUT = 0.1

      # Key codes
      #
      # @return [Hash[Symbol]]
      #
      # @api public
      attr_reader :keys

      # Escape codes
      #
      # @return [Array[Integer]]
      #
      # @api public
      attr_reader :escape_codes

      def initialize(input)
        @input = input
        @mode  = Mode.new(input)
        @keys  = Keys.ctrl_keys.merge(Keys.keys)
        @escape_codes = [[ESC.ord], CSI.bytes.to_a, XTERM.bytes.to_a]
      end

      # Get a character from console with echo
      #
      # @param [Boolean] echo
      #   whether to echo input back or not, defaults to true
      # @param [Boolean] raw
      #   whether to use raw mode or not, defaults to false
      # @param [Boolean] nonblock
      #   whether to wait for input or not, defaults to false
      #
      # @return [String]
      #
      # @api private
      def get_char(echo: true, raw: false, nonblock: false)
        mode.raw(raw) do
          mode.echo(echo) do
            if nonblock
              input.wait_readable(TIMEOUT) ? input.getc : nil
            else
              input.getc
            end
          end
        end
      end

      protected

      attr_reader :mode

      attr_reader :input
    end # Console
  end # Reader
end # TTY
