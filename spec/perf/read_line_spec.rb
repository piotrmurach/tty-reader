# frozen_string_literal: true

require "rspec-benchmark"

RSpec.describe TTY::Reader, "#read_line" do
  include RSpec::Benchmark::Matchers

  let(:output) { StringIO.new }

  it "reads line at most 950x slower than gets method" do
    input = StringIO.new("abc\n")
    reader = described_class.new(input: input, output: output)

    expect {
      input.rewind
      reader.read_line
    }.to perform_slower_than {
      input.rewind
      input.gets
    }.at_most(950).times
  end

  it "reads line with prompt at most 1000x slower than gets method" do
    input = StringIO.new("abc\n")
    reader = described_class.new(input: input, output: output)
    prompt = ">>"

    expect {
      input.rewind
      reader.read_line(prompt)
    }.to perform_slower_than {
      input.rewind
      input.gets
    }.at_most(1000).times
  end

  it "reads line allocating no more than 311 objects" do
    input = StringIO.new("abc\n")
    reader = described_class.new(input: input, output: output)

    expect {
      reader.read_line
    }.to perform_allocation(311).objects
  end

  it "reads line with prompt allocating no more than 323 objects" do
    input = StringIO.new("abc\n")
    reader = described_class.new(input: input, output: output)
    prompt = ">>"

    expect {
      reader.read_line(prompt)
    }.to perform_allocation(323).objects
  end
end
