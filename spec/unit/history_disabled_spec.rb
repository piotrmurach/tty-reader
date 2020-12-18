# frozen_string_literal: true

RSpec.describe TTY::Reader, "#with_history_disabled" do
  let(:input) { StringIO.new }
  let(:out)   { StringIO.new }
  let(:env)   { { "TTY_TEST" => true } }

  let(:reader) {
    described_class.new(input: input, output: out, env: env,
                        track_history: false)
  }

  it "leaves the line alone on :up" do
    input << "abc\e[Adef\n"
    input.rewind
    chars = []
    lines = []
    reader.on(:keypress) { |event| chars << event.value; lines << event.line.to_s }
    answer = reader.read_line

    expect(chars).to eq(%W(a b c \e[A d e f \n))
    expect(lines).to eq(%W(a ab abc abc abcd abcde abcdef abcdef\n))
    expect(answer).to eq("abcdef\n")
  end

  it "leaves the line alone on :down" do
    input << "abc\e[Bdef\n"
    input.rewind
    chars = []
    lines = []
    reader.on(:keypress) { |event| chars << event.value; lines << event.line.to_s }
    answer = reader.read_line

    expect(chars).to eq(%W(a b c \e[B d e f \n))
    expect(lines).to eq(%W(a ab abc abc abcd abcde abcdef abcdef\n))
    expect(answer).to eq("abcdef\n")
  end
end
