# Change log

## [v0.2.0] - 2017-xx-xx

### Added
* Add home & end keys support in #read_line
* Add tty-screen & tty-cursor dependencies

### Changed
* Change Codes to Keys and inverse keys lookup to allow for different system keys matching same name.
* Change Reader#initialize to only accept options and make input and output options as well.

### Fixed
* Fix issues with recognising :home & :end keys on different terminals
* Fix #read_line to work with strings spanning multiple screen widths and allow copy-pasting a long string without repeating prompt

## [v0.1.0] - 2017-08-30

* Initial implementation and release

[v0.2.0]: https://github.com/piotrmurach/tty-reader/compare/v0.1.0...v0.2.0
[v0.1.0]: https://github.com/piotrmurach/tty-reader/compare/v0.1.0
