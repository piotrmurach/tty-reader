# frozen_string_literal: true

RSpec.describe TTY::Reader, "#read_multiline" do
  let(:input)  { StringIO.new }
  let(:output) { StringIO.new }
  let(:env)    { { "TTY_TEST" => true } }

  subject(:reader) { described_class.new(input: input, output: output, env: env) }

  it "reads no lines" do
    input << "\C-d"
    input.rewind
    answer = reader.read_multiline
    expect(answer).to eq([])
  end

  it "reads a line and terminates on Ctrl+d" do
    input << "Single line\C-d"
    input.rewind
    answer = reader.read_multiline
    expect(answer).to eq(["Single line"])
  end

  it "reads a line and terminates on Ctrl+z" do
    input << "Single line\C-z"
    input.rewind
    answer = reader.read_multiline
    expect(answer).to eq(["Single line"])
  end

  it "reads few lines" do
    input << "First line\nSecond line\nThird line\n\C-d"
    input.rewind
    answer = reader.read_multiline
    expect(answer).to eq(["First line\n", "Second line\n", "Third line\n"])
  end

  it "skips empty lines" do
    input << "\n\nFirst line\n\n\n\n\nSecond line\C-d"
    input.rewind
    answer = reader.read_multiline
    expect(answer).to eq(["First line\n", "Second line"])
  end

  it "reads and yiels every line" do
    input << "First line\nSecond line\nThird line\C-z"
    input.rewind
    lines = []
    reader.read_multiline { |line| lines << line }
    expect(lines).to eq(["First line\n", "Second line\n", "Third line"])
  end

  it "reads multibyte lines" do
    input << "국경의 긴 터널을 빠져나오자\n설국이었다.\C-d"
    input.rewind

    lines = reader.read_multiline

    expect(lines).to eq(["국경의 긴 터널을 빠져나오자\n", "설국이었다."])
  end

  it "reads lines with a prompt" do
    input << "1\n2\n3\C-d"
    input.rewind

    lines = reader.read_multiline(">> ")

    expect(lines).to eq(["1\n", "2\n", "3"])
    expect(output.string).to eq([
      ">> ",
      "\e[2K\e[1G>> 1",
      "\e[2K\e[1G>> 1\n",
      ">> ",
      "\e[2K\e[1G>> 2",
      "\e[2K\e[1G>> 2\n",
      ">> ",
      "\e[2K\e[1G>> 3",
    ].join)
  end

  it "reads lines with echo off" do
    input << "1\n2\n3\n"
    input.rewind

    lines = reader.read_multiline(echo: false)

    expect(lines).to eq(["1\n", "2\n", "3\n"])
    expect(output.string).to eq("\n\n\n")
  end

  it "sets initial input line" do
    input << "aa\nbb\n"
    input.rewind

    lines = reader.read_multiline("> ", value: "xx")

    expect(lines).to eq(["xxaa\n", "bb\n"])
    expect(output.string).to eq([
      "> xx",
      "\e[2K\e[1G> xxa",
      "\e[2K\e[1G> xxaa",
      "\e[2K\e[1G> xxaa\n",
      "> ",
      "\e[2K\e[1G> b",
      "\e[2K\e[1G> bb",
      "\e[2K\e[1G> bb\n",
      "> "
    ].join)
  end
end
