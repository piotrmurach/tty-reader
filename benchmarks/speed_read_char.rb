# frozen_string_literal: true

require "stringio"
require "benchmark/ips"

require_relative "../lib/tty-reader"

input = StringIO.new("a")
output = StringIO.new
$stdin = input
reader = TTY::Reader.new(input: input, output: output)

Benchmark.ips do |x|
  x.report("getc") do
    input.rewind
    $stdin.getc
  end

  x.report("read_char") do
    input.rewind
    reader.read_char
  end

  x.compare!
end

# v0.9.0
#
# Calculating -------------------------------------
#                 getc      2.557M (± 4.6%) i/s -     12.785M in   5.011706s
#            read_char     14.553k (± 2.3%) i/s -     72.875k in   5.010291s
#
# Comparison:
#                 getc:  2556748.9 i/s
#            read_char:    14553.1 i/s - 175.68x  slower
#
# v0.1.0
#
# Calculating -------------------------------------
#                 getc     52462 i/100ms
#            read_char       751 i/100ms
# -------------------------------------------------
#                 getc  2484819.4 (±4.1%) i/s -   12433494 in   5.013438s
#            read_char     7736.4 (±2.9%) i/s -      39052 in   5.052628s
#
# Comparison:
#                 getc:  2484819.4 i/s
#            read_char:     7736.4 i/s - 321.19x slower
