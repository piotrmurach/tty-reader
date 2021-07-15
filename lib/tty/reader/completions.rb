# frozen_string_literal: true

require "forwardable"

module TTY
  class Reader
    # Responsible for storing and navigating completion suggestions
    #
    # @api private
    class Completions
      include Enumerable
      extend Forwardable

      def_delegators :@completions, :size, :empty?

      # Create a Completions collection
      #
      # @api public
      def initialize
        @completions = []
        @index = 0
      end

      # Clear current completions
      #
      # @api public
      def clear
        @completions.clear
        @index = 0
      end

      # Check whether the current index is at the first completion or not
      #
      # @return [Boolean]
      #
      # @api public
      def first?
        @index.zero?
      end

      # Check whether the current index is at the last completion or not
      #
      # @return [Boolean]
      #
      # @api public
      def last?
        @index == size - 1
      end

      # Add completion suggestions
      #
      # @param [Array<String>] suggestions
      #   the suggestions to add
      #
      # @api public
      def concat(suggestions)
        suggestions.each { |suggestion| @completions << suggestion.dup }
      end

      # Iterate over all completions
      #
      # @api public
      def each(&block)
        if block_given?
          @completions.each(&block)
        else
          @completions.to_enum
        end
      end

      # Retrieve completion at the current index
      #
      # @return [String]
      #
      # @api public
      def get
        @completions[@index]
      end

      # Move index to the next completion
      #
      # @api public
      def next
        return if size.zero?

        if @index == size - 1
          @index = 0
        else
          @index += 1
        end
      end

      # Move index to the previous completion
      #
      # @api public
      def previous
        return if size.zero?

        if @index.zero?
          @index = size - 1
        else
          @index -= 1
        end
      end
    end # Completions
  end # Reader
end # TTY
