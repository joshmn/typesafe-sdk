# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "typesafe/sdk/version"

Gem::Specification.new do |spec|
  spec.name = "typesafe-sdk"
  spec.version = Typesafe::SDK::VERSION
  spec.authors = ["Josh"]
  spec.email = ["git@josh.mn"]

  spec.summary = "Ruby client for the TypeSafe System One API"
  spec.description = "Ask TypeSafe models typed Noul, Choice, and Score questions about text or structured state " \
                     "and get calibrated, structured answers back. Built on the Ruby standard library, with Zeitwerk " \
                     "for loading."
  spec.homepage = "https://github.com/joshmn/typesafe-sdk"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/joshmn/typesafe-sdk"
  spec.metadata["changelog_uri"] = "https://github.com/joshmn/typesafe-sdk/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://docs.typesafe.ai/"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ Gemfile Rakefile .gitignore .github/])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "zeitwerk", ">= 2.6.2", "< 3"
end
