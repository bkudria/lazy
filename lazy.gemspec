require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'lazy'
  s.version = "0.2.0"
  s.platform = Gem::Platform::RUBY
  s.summary = "Lazy evaluation for Ruby"
  s.files = [ 'lazy.rb', 'lazy/stream.rb' ]
  s.autorequire = 'lazy'
  s.author = "MenTaLguY"
  s.email = "mental@rydia.net"
  s.homepage = "http://moonbase.rydia.net/software/lazy.rb"
end

if $0 == __FILE__
  Gem::Builder.new(spec).build
end

