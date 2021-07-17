# frozen_string_literal: true

RSpec.describe TTY::Reader, "complete word" do
  let(:input)  { StringIO.new }
  let(:output) { StringIO.new }
  let(:env)    { {"TTY_TEST" => true} }
  let(:left)   { "\e[D" }
  let(:completion_handler) {
    ->(word) { @completions.grep(/\A#{Regexp.escape(word)}/) }
  }
  let(:options) {
    {input: input, output: output, env: env,
     completion_handler: completion_handler}
  }

  subject(:reader) { described_class.new(**options) }

  it "finds no completions for a word" do
    @completions = %w[aa ab ac]
    input << "x" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x\n")
    output.rewind
    expect(output.string).to eq("\e[2K\e[1Gx\e[2K\e[1Gx\e[2K\e[1Gx\n")
  end

  it "completes an empty line with the first suggestion" do
    @completions = %w[aa ab ac]
    input << "" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("aa\n")
    output.rewind
    expect(output.string).to eq("\e[2K\e[1Gaa\e[2K\e[1Gaa\n")
  end

  it "completes space inside line with the first suggestion" do
    @completions = %w[aa ab ac]
    input << "x" << " " << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x aa\n")
  end

  it "completes a word using the first suggestion" do
    @completions = %w[aa ab ac]
    input << "x" << " " << "a" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x aa\n")
    expect(reader.completion_handler).to eq(completion_handler)
  end

  it "completes a word using the next suggestion" do
    @completions = %w[aa ab ac]
    reader = described_class.new(input: input, output: output, env: env)
    reader.completion_handler = completion_handler
    input << "x" << " " << "a" << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x ab\n")
    expect(reader.completion_handler).to eq(completion_handler)
  end

  it "completes a word using the last suggestion" do
    @completions = %w[aa ab ac]
    input << "x " << "a" << "\t" << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x ac\n")
  end

  it "cycles through completions back to the initial word" do
    @completions = %w[aa ab ac]
    input << "x " << "a" << "\t" << "\t" << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x a\n")
  end

  it "cycles through completions and completes using the first suggestion" do
    @completions = %w[aa ab ac]
    input << "x " << "a" << "\t" << "\t" << "\t" << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x aa\n")
  end

  it "resets suggestions when a new character is entered" do
    @completions = %w[aa ab ac]
    input << "x " << "a" << "\t" << "\b" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x aa\n")
  end

  it "completes edited text within a line" do
    @completions = %w[aa ab ac]
    input << "bb" << left << left << " " << left
    input << "a" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("aa bb\n")
  end

  it "completes within a word" do
    @completions = %w[aa ab ac]
    input << "x " << "aa" << left << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x aba\n")
  end

  it "completes a multiline input " do
    @completions = %w[aa ab ac]
    input << "a" << "\t" << "\n"
    input << "a" << "\t" << "\t" << "\C-d"
    input.rewind

    answer = reader.read_multiline

    expect(answer).to eq(%W[aa\n ab])
  end

  it "adds space suffix to suggested word completion on the first tab" do
    @completions = %w[aa ab ac]
    options[:completion_suffix] = " "
    reader = described_class.new(**options)
    input << "x " << "a" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x aa \n")
  end

  it "adds space suffix to suggested word completion on the second tab" do
    @completions = %w[aa ab ac]
    options[:completion_suffix] = " "
    reader = described_class.new(**options)
    input << "x " << "a" << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x ab \n")
  end

  it "skips adding space suffix to the original word" do
    @completions = %w[aa ab ac]
    options[:completion_suffix] = " "
    reader = described_class.new(**options)
    input << "x " << "a" << "\t" << "\t" << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x a\n")
    expect(reader.completion_suffix).to eq(" ")
  end

  it "adds two chars suffix to suggested word completion" do
    @completions = %w[aa ab ac]
    reader = described_class.new(**options)
    reader.completion_suffix = "??"
    input << "x " << "a" << "\t" << "\t" << "\n"
    input.rewind

    answer = reader.read_line

    expect(answer).to eq("x ab??\n")
    expect(reader.completion_suffix).to eq("??")
  end
end
