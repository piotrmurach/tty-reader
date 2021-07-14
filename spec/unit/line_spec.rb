# frozen_string_literal: true

RSpec.describe TTY::Reader::Line do
  it "is empty by default" do
    line = described_class.new

    expect(line.prompt).to eq("")
    expect(line.text).to eq("")
    expect(line.size).to eq(0)
    expect(line.to_s).to eq("")
  end

  it "provides access to the prompt" do
    line = described_class.new("aaa", prompt: ">> ")
    expect(line.prompt).to eq(">> ")
    expect(line.text).to eq("aaa")
    expect(line.size).to eq(6)
    expect(line.to_s).to eq(">> aaa")
  end

  it "inserts characters inside a line" do
    line = described_class.new("aaaaa")

    line[0] = "test"
    expect(line.text).to eq("testaaaaa")

    line[4..6] = ""
    expect(line.text).to eq("testaa")
  end

  it "moves cursor left and right" do
    line = described_class.new("aaaaa")

    5.times { line.left }
    expect(line.cursor).to eq(0)
    expect(line.start?).to eq(true)

    line.left(5)
    expect(line.cursor).to eq(0)

    line.right(20)
    expect(line.cursor).to eq(5)
    expect(line.end?).to eq(true)
  end

  it "inserts char at start of the line" do
    line = described_class.new("aaaaa")
    expect(line.cursor).to eq(5)

    line[0] = "b"
    expect(line.cursor).to eq(1)
    expect(line.text).to eq("baaaaa")

    line.insert("b")
    expect(line.text).to eq("bbaaaaa")
  end

  it "inserts char at end of the line" do
    line = described_class.new("aaaaa")
    expect(line.cursor).to eq(5)

    line[4] = "b"
    expect(line.cursor).to eq(5)
    expect(line.text).to eq("aaaaba")
  end

  it "inserts char inside the line" do
    line = described_class.new("aaaaa")
    expect(line.cursor).to eq(5)

    line[2] = "b"
    expect(line.cursor).to eq(3)
    expect(line.text).to eq("aabaaa")
  end

  it "inserts char outside of the line size" do
    line = described_class.new("aaaaa")
    expect(line.cursor).to eq(5)

    line[10] = "b"
    expect(line.cursor).to eq(11)
    expect(line.text).to eq("aaaaa     b")
  end

  it "inserts chars in empty string" do
    line = described_class.new("")
    expect(line.cursor).to eq(0)

    line.insert("a")
    expect(line.cursor).to eq(1)

    line.insert("b")
    expect(line.cursor).to eq(2)
    expect(line.to_s).to eq("ab")

    line.insert("cc")
    expect(line.cursor).to eq(4)
    expect(line.to_s).to eq("abcc")
  end

  it "inserts characters with #insert call" do
    line = described_class.new("aaaaa")
    expect(line.cursor).to eq(5)

    line.left(2)
    expect(line.cursor).to eq(3)

    line.insert(" test ")
    expect(line.text).to eq("aaa test aa")
    expect(line.cursor).to eq(9)

    line.right
    expect(line.cursor).to eq(10)
  end

  it "removes char before current cursor position" do
    line = described_class.new("abcdef")
    expect(line.cursor).to eq(6)

    line.remove(2)
    expect(line.text).to eq("abcd")
    expect(line.cursor).to eq(4)

    line.left
    line.left
    line.remove
    expect(line.text).to eq("acd")
    expect(line.cursor).to eq(1)

    line.insert("x")
    expect(line.text).to eq("axcd")
  end

  it "deletes char under current cursor position" do
    line = described_class.new("abcdef")

    line.left(3)
    line.delete
    expect(line.text).to eq("abcef")

    line.right
    line.delete
    expect(line.text).to eq("abce")

    line.left(4)
    line.delete
    expect(line.text).to eq("bce")
  end

  it "replaces current line with new preserving cursor" do
    line = described_class.new("x" * 6)
    expect(line.text).to eq("xxxxxx")
    expect(line.cursor).to eq(6)
    expect(line.mode).to eq(:edit)
    expect(line.editing?).to eq(true)

    line.replace("y" * 8)
    expect(line.text).to eq("y" * 8)
    expect(line.cursor).to eq(8)
    expect(line.replacing?).to eq(true)

    line.insert("z")
    expect(line.text).to eq("y" * 8 + "z")
    expect(line.cursor).to eq(9)
    expect(line.editing?).to eq(true)
  end

  context "#word and #word_to_complete" do
    it "returns empty string when line is empty" do
      line = described_class.new("")

      expect(line.word).to eq("")
      expect(line.word_to_complete).to eq("")
      expect(line.word_start_pos).to eq(0)
      expect(line.word_end_pos).to eq(0)
    end

    it "matches the line content without separators" do
      line = described_class.new("foo")

      expect(line.word).to eq("foo")
      expect(line.word_to_complete).to eq("foo")
      expect(line.word_start_pos).to eq(0)
      expect(line.word_end_pos).to eq(2)
    end

    it "finds a word when the cursor is at the start of the line" do
      line = described_class.new("foo bar baz")

      line.move_to_start

      expect(line.word).to eq("foo")
      expect(line.word_to_complete).to eq("")
      expect(line.word_start_pos).to eq(0)
      expect(line.word_end_pos).to eq(2)
    end

    it "finds a word when the cursor is after the start of the line" do
      line = described_class.new("foo bar baz")

      line.move_to_start
      line.right(2)

      expect(line.word).to eq("foo")
      expect(line.word_to_complete).to eq("fo")
      expect(line.word_start_pos).to eq(0)
      expect(line.word_end_pos).to eq(2)
    end

    it "finds a word when the cursor is at the end of the line" do
      line = described_class.new("foo bar baz")

      expect(line.word).to eq("baz")
      expect(line.word_to_complete).to eq("baz")
      expect(line.word_start_pos).to eq(8)
      expect(line.word_end_pos).to eq(10)
    end

    it "finds a word when the cursor is in the middle of the line" do
      line = described_class.new("foo bar baz")

      line.move_to_start
      line.right(6)

      expect(line.word).to eq("bar")
      expect(line.word_to_complete).to eq("ba")
      expect(line.word_start_pos).to eq(4)
      expect(line.word_end_pos).to eq(6)
    end

    it "finds a word when a cursor is inside the last word" do
      line = described_class.new("foo bar baz")

      line.move_to_start
      line.right(10)

      expect(line.word).to eq("baz")
      expect(line.word_to_complete).to eq("ba")
      expect(line.word_start_pos).to eq(8)
      expect(line.word_end_pos).to eq(10)
    end

    it "finds a word before a break character" do
      line = described_class.new("foo bar")

      line.move_to_start
      line.right(3)

      expect(line.word).to eq("foo")
      expect(line.word_to_complete).to eq("foo")
      expect(line.word_start_pos).to eq(0)
      expect(line.word_end_pos).to eq(2)
    end

    it "finds no word to complete when cursor is on a break character" do
      line = described_class.new("foo bar")

      line.move_to_start
      line.right(3)

      expect(line.word(before: false)).to eq("bar")
      expect(line.word_to_complete(before: false)).to eq("")
      expect(line.word_start_pos(before: false)).to eq(4)
      expect(line.word_end_pos(from: line.cursor + 1)).to eq(6)
    end

    it "finds a word based on custom break character" do
      line = described_class.new("aa\tbb\ncc\"dd\\ee'ff`gg@" \
                                 "hh$ii>jj<kk=ll|mm&nn{oo(pp")

      line.move_to_start
      line.right(2)
      expect(line.word).to eq("aa")
      expect(line.word_to_complete).to eq("aa")

      %w[bb cc dd ee ff gg hh ii jj kk ll mm nn oo pp].each do |word|
        line.right(3)
        expect(line.word).to eq(word)
        expect(line.word_to_complete).to eq(word)
      end
    end

    it "finds a word using a custom break character" do
      line = described_class.new("foo_bar", separator: /_/)

      line.move_to_start
      line.right(3)

      expect(line.word).to eq("foo")
      expect(line.word_to_complete).to eq("foo")
      expect(line.word_start_pos).to eq(0)
      expect(line.word_end_pos).to eq(2)
    end

    it "finds a whole word when looking after cursor position" do
      line = described_class.new("foo bar")

      line.move_to_start
      line.right(4)

      expect(line.word).to eq("bar")
      expect(line.word_to_complete).to eq("")
      expect(line.word_start_pos).to eq(4)
      expect(line.word_end_pos).to eq(6)
    end
  end
end
