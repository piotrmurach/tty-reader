# frozen_string_literal: true

require_relative "../lib/tty-reader"

reader = TTY::Reader.new

reader.on(:keyctrl_x, :keyescape) do
  puts "Exiting..."
  exit
end

loop do
  reader.read_line("one\ntwo\nthree> ")
end
