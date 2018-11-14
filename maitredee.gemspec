
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "maitredee/version"

Gem::Specification.new do |spec|
  spec.name          = "maitredee"
  spec.version       = Maitredee::VERSION
  spec.authors       = ["Plated Devs"]
  spec.email         = ["dev@plated.com"]

  spec.summary       = %q{Opinionated pub/sub framework}
  #spec.description   = %q{Opinionated pub/sub framework}
  spec.homepage      = "https://github.com/plated/maitredee"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "aws-sdk-sns"
  spec.add_dependency "json_schemer", "~> 0.1.8"
  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
