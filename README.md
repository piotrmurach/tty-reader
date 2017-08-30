# TTY::Reader [![Gitter](https://badges.gitter.im/Join%20Chat.svg)][gitter]

[![Gem Version](https://badge.fury.io/rb/tty-reader.svg)][gem]
[![Build Status](https://secure.travis-ci.org/piotrmurach/tty-reader.svg?branch=master)][travis]
[![Build status](https://ci.appveyor.com/api/projects/status/4cguoiah5dprbq7n?svg=true)][appveyor]
[![Code Climate](https://codeclimate.com/github/piotrmurach/tty-reader/badges/gpa.svg)][codeclimate]
[![Coverage Status](https://coveralls.io/repos/github/piotrmurach/tty-reader/badge.svg)][coverage]
[![Inline docs](http://inch-ci.org/github/piotrmurach/tty-reader.svg?branch=master)][inchpages]

[gitter]: https://gitter.im/piotrmurach/tty
[gem]: http://badge.fury.io/rb/tty-reader
[travis]: http://travis-ci.org/piotrmurach/tty-reader
[appveyor]: https://ci.appveyor.com/project/piotrmurach/tty-reader
[codeclimate]: https://codeclimate.com/github/piotrmurach/tty-reader
[coverage]: https://coveralls.io/github/piotrmurach/tty-reader
[inchpages]: http://inch-ci.org/github/piotrmurach/tty-reader

> A pure Ruby library that provides a set of methods for processing keyboard input in character, line and multiline modes. In addition it maintains history of entered input with an ability to recall and re-edit those inputs and register to listen for keystrokes.

**TTY::Reader** provides independent reader component for [TTY](https://github.com/piotrmurach/tty) toolkit.

## Features

* Reading keystroke
* Line editing
* Multiline input
* History management
* Ability to register for key events

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tty-reader'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tty-reader

## Usage

```ruby
reader = TTY::Reader.new
```

## keystroke

```ruby
reader.read_char
reader.read_keypress
```

## line

```ruby
reader.read_line
```

## multiline

```ruby
reader.read_multiline
```

## events

You can register to listen on a key pressed events. This can be done by calling `on` with a event name:

```ruby
reader.on(:keypress) { |event| .... }
```

The event object is yielded to a block whenever particular key event fires. The event has `key` and `value` methods. Further, the `key` responds to following messages:

* `name`  - the name of the event such as :up, :down, letter or digit
* `meta`  - true if event is non-standard key associated
* `shift` - true if shift has been pressed with the key
* `ctrl`  - true if ctrl has been pressed with the key

For example, to add listen to vim like navigation keys, one would do the following:

```ruby
reader.on(:keypress) do |event|
  if event.value == 'j'
    ...
  end

  if event.value == 'k'
    ...
  end
end
```

You can subscribe to more than one event:

```ruby
prompt.on(:keypress) { |key| ... }
      .on(:keydown)  { |key| ... }
```

The available events are:

* `:keypress`
* `:keydown`
* `:keyup`
* `:keyleft`
* `:keyright`
* `:keynum`
* `:keytab`
* `:keyenter`
* `:keyreturn`
* `:keyspace`
* `:keyescape`
* `:keydelete`
* `:keybackspace`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/tty-reader. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Tty::Reader project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/piotrmurach/tty-reader/blob/master/CODE_OF_CONDUCT.md).

## Copyright

Copyright (c) 2017 Piotr Murach. See LICENSE for further details.
