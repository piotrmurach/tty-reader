RSpec.describe TTY::Reader, '#subscribe' do
  let(:input)  { StringIO.new }
  let(:output) { StringIO.new }

  it "subscribes to receive events" do
    stub_const("Context", Class.new do
      def initialize(events)
        @events = events
      end

      def keypress(event)
        @events << [:keypress, event.value]
      end
    end)

    reader = TTY::Reader.new(input, output)
    events = []
    context = Context.new(events)
    reader.subscribe(context)

    input << "aa\n"
    input.rewind
    answer = reader.read_line(echo: false)

    expect(answer).to eq("aa\n")
    expect(events).to eq([
      [:keypress, "a"],
      [:keypress, "a"],
      [:keypress, "\n"]
    ])
  end
end
