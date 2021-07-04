# frozen_string_literal: true

RSpec.describe TTY::Reader, "#read_line" do
  let(:input)  { StringIO.new }
  let(:output) { StringIO.new }
  let(:env)    { { "TTY_TEST" => true } }
  let(:up)     { "\e[A" }
  let(:down)   { "\e[B" }

  subject(:reader) { described_class.new(input: input, output: output, env: env) }

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

  it "exits input with a custom Ctrl+O key" do
    input << "a" << "\C-o"
    input.rewind
    chars = []

    reader.on(:keypress) { |event| chars << event.value }

    answer = reader.read_line(exit_keys: %i[ctrl_o])

    expect(answer).to eq("a")
    expect(chars).to eq(%W(a \C-o))
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

    it "restores non-empty input line when history has no more lines" do
      input << "ab\n" << "cd" << up << down << "\n"
      input.rewind
      chars = []
      lines = []

      reader.on(:keypress) do |event|
        chars << event.value
        lines << event.line
      end

      reader.read_line
      answer = reader.read_line

      expect(chars).to eq(%W(a b \n c d #{up} #{down} \n))
      expect(lines).to eq(%W(a ab ab\n c cd ab cd cd\n))
      expect(answer).to eq("cd\n")
    end

    it "limits history size" do
      reader = described_class.new(input: input, output: output, env: env,
                                   history_size: 2)
      input << "line1\nline2\nline3\n"
      input << up << up << up << "\n"
      input.rewind
      answer = nil

      4.times do
        answer = reader.read_line
      end

      expect(answer).to eq("line2\n")
    end

    it "allows duplicates in history" do
      reader = described_class.new(input: input, output: output, env: env,
                                   history_duplicates: true)
      input << "aa\nbb\naa\n"
      input << up << up << up << "\n"
      input.rewind
      answer = nil
      lines = []

      reader.on(:keypress) { |event| lines << event.line }

      4.times do
        answer = reader.read_line
      end

      expect(answer).to eq("aa\n")
      expect(lines).to eq(%W(a aa aa\n b bb bb\n a aa aa\n aa bb aa aa\n))
    end

    it "retrieves previous history line with up arrow key" do
      input << "aa\n" << "bb\n" << "cc\n"
      input << up << up << "\n"
      input.rewind
      answer = nil

      4.times do
        answer = reader.read_line
      end

      expect(answer).to eq("bb\n")
    end

    it "retrieves next history line with down arrow key" do
      input << "aa\n" << "bb\n" << "cc\n"
      input << up << up << down << down << up << "\n"
      input.rewind
      answer = nil

      4.times do
        answer = reader.read_line
      end

      expect(answer).to eq("cc\n")
    end

    it "edits line in history and uses it without affecting history" do
      input << "aa\n" << "bb\n"
      input << up << up << "\bx" << "\n"
      input << up << up << up << "\n"
      input.rewind
      answer = nil
      lines = []

      reader.on(:keypress) { |event| lines << event.line }

      3.times do
        answer = reader.read_line
      end

      expect(answer).to eq("ax\n")

      answer = reader.read_line

      expect(answer).to eq("aa\n")
      expect(lines).to eq(%W(a aa aa\n b bb bb\n bb aa a ax ax\n ax bb aa aa\n))
    end

    it "edits line in history and navigates away and back to it to use it" do
      input << "aa\n" << "bb\n"
      input << up << "\bx" << up << down << "\n"
      input.rewind
      answer = nil
      lines = []

      reader.on(:keypress) { |event| lines << event.line }

      3.times do
        answer = reader.read_line
      end

      expect(answer).to eq("bx\n")
      expect(lines).to eq(%W(a aa aa\n b bb bb\n bb b bx aa bx bx\n))
    end

    it "edits line in history but doesn't use it and enters a new line of text" do
      input << "aa\n" << "bb\n"
      input << up << up << "\bx" << down << down << "cc\n"
      input << up << up << up << "\n"
      input.rewind
      answer = nil
      lines = []

      reader.on(:keypress) { |event| lines << event.line }

      3.times do
        answer = reader.read_line
      end

      expect(answer).to eq("cc\n")

      answer = reader.read_line

      expect(answer).to eq("ax\n")
      expect(lines).to eq(%W(a aa aa\n b bb bb\n bb aa a ax bb #{""} c cc cc\n
                             cc bb ax ax\n))
    end
  end
end
