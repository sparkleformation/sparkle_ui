$:.unshift File.join(File.expand_path(File.dirname(__FILE__)), 'lib')

require 'sparkle_ui/version'

Gem::Specification.new do |s|
  s.name = 'sparkle_ui'
  s.version = SparkleUi::VERSION.version
  s.summary = 'Sparkle Builder'
  s.author = 'Chris Roberts'
  s.email = 'chris@hw-ops.com'
  s.homepage = 'https://github.com/heavywater/sparkle_ui'
  s.description = 'Base UI for sparkle'
  s.require_path = 'lib'
  s.files = Dir['{lib,app,config}/**/**/*'] + %w(sparkle_ui.gemspec README.md CHANGELOG.md)

  s.add_dependency 'rails', '~> 4.0.0'
  s.add_dependency 'sparkle_formation'
  s.add_dependency 'sfn'
  s.add_dependency 'window_rails', '~> 1.0'
  s.add_dependency 'will_paginate'
  s.add_dependency 'content_for_in_controllers'
  s.add_dependency 'will_paginate-bootstrap'
end
