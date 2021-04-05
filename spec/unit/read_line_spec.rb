# frozen_string_literal: true

RSpec.describe TTY::Reader, "#read_line" do
  let(:input)          { StringIO.new }
  let(:output)         { StringIO.new }
  let(:env)            { { "TTY_TEST" => true } }
  let(:completion)     { true }
  let(:completion_key) { :tab }

  subject(:reader) { described_class.new(input: input, output: output, env: env, completion: completion, completion_key: completion_key) }

  it "masks characters" do
    input << "password\n"
    input.rewind

    answer = reader.read_line(echo: false)

    expect(answer).to eq("password\n")
  end

  it "echoes characters back" do
    input << "password\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("password\n")
    expect(output.string).to eq([
      "\e[2K\e[1Gp",
      "\e[2K\e[1Gpa",
      "\e[2K\e[1Gpas",
      "\e[2K\e[1Gpass",
      "\e[2K\e[1Gpassw",
      "\e[2K\e[1Gpasswo",
      "\e[2K\e[1Gpasswor",
      "\e[2K\e[1Gpassword",
      "\e[2K\e[1Gpassword\n"
    ].join)
  end

  it "doesn't echo characters back" do
    input << "password\n"
    input.rewind

    answer = reader.read_line(echo: false)

    expect(answer).to eq("password\n")
    expect(output.string).to eq("\n")
  end

  it "displays a prompt before input" do
    input << "aa\n"
    input.rewind

    answer = reader.read_line(">> ")

    expect(answer).to eq("aa\n")
    expect(output.string).to eq([
      ">> ",
      "\e[2K\e[1G>> a",
      "\e[2K\e[1G>> aa",
      "\e[2K\e[1G>> aa\n"
    ].join)
  end

  it "displays custom input with a prompt" do
    input << "aa\n"
    input.rewind

    answer = reader.read_line("> ", value: "xx")

    expect(answer).to eq("xxaa\n")
    expect(output.string).to eq([
      "> xx",
      "\e[2K\e[1G> xxa",
      "\e[2K\e[1G> xxaa",
      "\e[2K\e[1G> xxaa\n"
    ].join)
  end

  it "deletes characters when backspace pressed" do
    input << "aa\ba\bcc\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("acc\n")
  end

  it "finishes input with enter pressed inside the line" do
    input << "aaa" << "\e[D" << "\e[D" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("aaa\n")
  end

  it "reads multibyte line" do
    input << "한글"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("한글")
  end

  it "supports multiline prompts" do
    allow(TTY::Screen).to receive(:width).and_return(50)
    prompt = "one\ntwo\nthree"
    input << "aa\n"
    input.rewind

    answer = reader.read_line(prompt)

    expect(answer).to eq("aa\n")
    expect(output.string).to eq([
      prompt,
      "\e[2K\e[1G\e[1A" * 2,
      "\e[2K\e[1G",
      prompt + "a",
      "\e[2K\e[1G\e[1A" * 2,
      "\e[2K\e[1G",
      prompt + "aa",
      "\e[2K\e[1G\e[1A" * 2,
      "\e[2K\e[1G",
      prompt + "aa\n"
    ].join)
  end

  context "history navigation" do
    it "restores empty line when history has no more lines" do
      input << "ab\ncd\n\e[A\e[A\e[B\e[B\n"
      input.rewind
      chars = []
      lines = []
      answer = nil

      reader.on(:keypress) do |event|
        chars << event.value
        lines << event.line
      end

      3.times do
        answer = reader.read_line
      end

      expect(chars).to eq(%W(a b \n c d \n \e[A \e[A \e[B \e[B \n))
      expect(lines).to eq(%W(a ab ab\n c cd cd\n cd ab cd #{''} \n))
      expect(answer).to eq("\n")
    end

    it "buffers non-empty input and restores it back when history has no more lines" do
      input << "ab\ncd\e[A\e[B\n"
      input.rewind
      chars = []
      lines = []

      reader.on(:keypress) do |event|
        chars << event.value
        lines << event.line
      end

      reader.read_line
      answer = reader.read_line

      expect(chars).to eq(%W(a b \n c d \e[A \e[B \n))
      expect(lines).to eq(%W(a ab ab\n c cd ab cd cd\n))
      expect(answer).to eq("cd\n")
    end

    it "limits history size" do
      reader = described_class.new(input: input, output: output, env: env,
                                   history_size: 2)
      input << "line1\nline2\nline3\n"
      input << "\e[A" << "\e[A" << "\e[A" << "\n"
      input.rewind
      answer = nil

      4.times do
        answer = reader.read_line
      end

      expect(answer).to eq("line2\n")
    end
  end

  it "partially completes a word when completion is enabled and completion_key is triggered" do
    input << "a\t"
    input.rewind

    reader.completion_proc = ->(text) { ["aaaa", "aaab", "aaba"] }
    answer = reader.read_line(echo: false)

    expect(answer).to eq("aa")
  end

  it "fully completes a word at the end of the line text when completion is enabled and completion_key is triggered" do
    input << "aab\t"
    input.rewind

    reader.completion_proc = ->(text) { ["aaaa", "aaab", "aaba"] }
    answer = reader.read_line(echo: false)

    expect(answer).to eq("aaba\s")
  end

  it "fully completes a word within the line text when completion is enabled and completion_key is triggered" do
    input << "foo aab bar"
    input << "\e[D" << "\e[D" << "\e[D" << "\e[D" << "\t"
    input.rewind

    reader.completion_proc = ->(text) { ["aaaa", "aaab", "aaba"] }
    answer = reader.read_line(echo: false)

    expect(answer).to eq("foo aaba bar")
  end

  it "finalizes a word when completion is enabled and completion_key is triggered" do
    input << "aaaa\t"
    input.rewind

    reader.completion_proc = ->(text) { ["aaaa", "aaab", "aaba"] }
    answer = reader.read_line(echo: false)

    expect(answer).to eq("aaaa\s")
  end

  it "tries to complete a word when completion is enabled and completion_key is triggered and no input is given" do
    input << "\t"
    input.rewind

    reader.completion_proc = ->(text) { ["aaaa", "aaab", "aaba"] }
    answer = reader.read_line(echo: false)

    expect(answer).to eq("aa")
  end

  it "tries to complete a word completion is enabled and completion_key is triggered and no input is given after the last word in the line" do
    input << "word \t"
    input.rewind

    reader.completion_proc = ->(text) { ["aaaa", "aaab", "aaba"] }
    answer = reader.read_line(echo: false)

    expect(answer).to eq("word aa")
  end
end
