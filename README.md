# TTY::Reader [![Gitter](https://badges.gitter.im/Join%20Chat.svg)][gitter]

[![Gem Version](https://badge.fury.io/rb/tty-reader.svg)][gem]
[![Build Status](https://secure.travis-ci.org/piotrmurach/tty-reader.svg?branch=master)][travis]
[![Build status](https://ci.appveyor.com/api/projects/status/cj4owy2vlty2q1ko?svg=true)][appveyor]
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

> A pure Ruby library that provides a set of methods for processing keyboard input in character, line and multiline modes. In addition it maintains history of entered input with an ability to recall and re-edit those inputs and register to listen for keystroke events.

**TTY::Reader** provides independent reader component for [TTY](https://github.com/piotrmurach/tty) toolkit.

## Features

* Reading single keypress
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

* [1. Usage](#1-usage)
* [2. API](#2-api)
  * [2.1 read_keypress](#21-read_keypress)
  * [2.2 read_line](#22-read_line)
  * [2.3 read_multiline](#23-read_multiline)
  * [2.4 events](#24-events)
* [3. Configuration](#3-configuration)
  * [3.1 :interrupt](#31-interrupt)
  * [3.2 :track_history](#31-track_history)

## Usage

```ruby
reader = TTY::Reader.new
```

## API

### 2.1 read_keypress

To read a single key stroke from the user use `read_char` or `read_keypress`:

```ruby
reader.read_char
reader.read_keypress
```

## 2.2 read_line

To read a single line terminated by new line character use `read_line` like so:

```ruby
reader.read_line
```

## 2.3 read_multiline

To read more than one line terminated by `Ctrl+d` or `Ctrl+z` use `read_multiline`:

```ruby
reader.read_multiline
# => [ "line1", "line2", ... ]
```

## 2.4 events

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

## 3. Configuration

### 3.1. :interrupt

By default `InputInterrupt` error will be raised when the user hits the interrupt key(Control-C). However, you can customise this behaviour by passing the `:interrupt` option. The available options are:

* `:signal` - sends interrupt signal
* `:exit` - exists with status code
* `:noop` - skips handler
* custom proc

For example, to send interrupt signal do:

```ruby
reader = TTY::Reader.new(interrupt: :signal)
```

### 3.2. :track_history

The `read_line` and `read_multiline` provide history buffer that tracks all the lines entered during `TTY::Reader.new` interactions. The history buffer provides previoius or next lines when user presses up/down arrows respectively. However, if you wish to disable this behaviour use `:track_history` option like so:

```ruby
reader = TTY::Reader.new(track_history: false)
```

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
