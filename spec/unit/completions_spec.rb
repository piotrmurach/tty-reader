# frozen_string_literal: true

RSpec.describe TTY::Reader::Completions do
  it "has no suggestions by default" do
    completions = described_class.new

    expect(completions.empty?).to eq(true)
    expect(completions.size).to eq(0)
  end

  it "adds suggestions making copies of each one" do
    completions = described_class.new
    suggestions = %w[aa ab ac]

    completions.concat(suggestions)

    suggestions[0] = "ax"

    expect(completions.to_a).to eq(%w[aa ab ac])
    expect(completions.to_a).to_not eq(suggestions)
  end

  it "clears all suggestions" do
    completions = described_class.new
    suggestions = %w[aa ab ac]

    completions.concat(suggestions)

    expect(completions.empty?).to eq(false)
    expect(completions.size).to eq(3)

    completions.clear

    expect(completions.empty?).to eq(true)
    expect(completions.size).to eq(0)
  end

  it "navigates to the next completion" do
    completions = described_class.new
    completions.concat(%w[aa ab ac])

    expect(completions.get).to eq("aa")

    completions.next
    expect(completions.get).to eq("ab")
  end

  it "navigates to the previous completion" do
    completions = described_class.new
    completions.concat(%w[aa ab ac])

    completions.next
    expect(completions.get).to eq("ab")

    completions.previous
    expect(completions.get).to eq("aa")
  end

  it "cycles through completions forward" do
    completions = described_class.new
    suggestions = %w[aa ab ac]
    completions.concat(suggestions)

    suggestions.size.times { completions.next }

    expect(completions.get).to eq("aa")
  end

  it "cycles through completions backward" do
    completions = described_class.new
    suggestions = %w[aa ab ac]
    completions.concat(suggestions)

    suggestions.size.times { completions.previous }

    expect(completions.get).to eq("aa")
  end

  it "checks whether index is at the first completion" do
    completions = described_class.new
    suggestions = %w[aa ab ac]
    completions.concat(suggestions)

    expect(completions.first?).to eq(true)

    completions.next
    expect(completions.first?).to eq(false)
  end

  it "checks whether index is at the last completion" do
    completions = described_class.new
    suggestions = %w[aa ab ac]
    completions.concat(suggestions)

    expect(completions.last?).to eq(false)

    2.times { completions.next }
    expect(completions.last?).to eq(true)
  end
end
