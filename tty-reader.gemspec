# encoding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "tty/reader/version"

Gem::Specification.new do |spec|
  spec.name          = "tty-reader"
  spec.version       = TTY::Reader::VERSION
  spec.authors       = ["Piotr Murach"]
  spec.email         = [""]
  spec.summary       = %q{A set of methods for processing keyboard input in character, line and multiline modes.}
  spec.description   = %q{A set of methods for processing keyboard input in character, line and multiline modes. In addition it maintains history of entered input with an ability to recall and re-edit those inputs and register to listen for keystrokes.}
  spec.homepage      = "https://piotrmurach.github.io/tty"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "wisper", "~> 2.0.0"
  spec.add_dependency "tty-screen"
  spec.add_dependency "tty-cursor"

  spec.add_development_dependency "bundler", ">= 1.5.0", "< 2.0"
  spec.add_development_dependency "rake",    "~> 10.0"
  spec.add_development_dependency "rspec",   "~> 3.0"
end
