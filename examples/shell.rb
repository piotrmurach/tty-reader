# frozen_string_literal: true

require_relative "../lib/tty-reader"

puts "*** TTY::Reader Shell ***"
puts "Press Ctrl-X or ESC to exit"

reader = TTY::Reader.new

reader.on(:keyctrl_x, :keyescape) do
  puts "Exiting..."
  exit
end

loop do
  line = reader.read_line("=> ")
  break if line =~ /^exit/i
end
