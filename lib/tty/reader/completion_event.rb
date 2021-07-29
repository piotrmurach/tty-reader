# frozen_string_literal: true

module TTY
  class Reader
    class CompletionEvent
      # The suggested word completion
      attr_reader :completion

      # The completion suggestions
      attr_reader :completions

      # The line with word to complete
      attr_reader :line

      # The initial word to complete
      attr_reader :word

      # Create a CompletionEvent
      #
      # @param [Completer] completer
      #   the word completer
      # @param [String] completion
      #   the word completion
      # @param [String] line
      #   the line with the word to complete
      #
      # @api public
      def initialize(completer, completion, line)
        @completion = completion
        @completions = completer.completions.to_a
        @line = line
        @word = completer.word
      end
    end # CompletionEvent
  end # Reader
end # TTY
