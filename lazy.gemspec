require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'lazy'
  s.version = "1.0"
  s.platform = Gem::Platform::RUBY
  s.summary = "Lazy evaluation for Ruby"
  s.description = "lazy.rb is a library providing lazy evaluation via promise/demand, asynchronous evaluation, and implicit evaluation of deferred computations."
  s.has_rdoc = true
  s.extra_rdoc_files = %w(README)
  s.rdoc_options = %w(--main README)
  s.files = Dir['**/*.rb'] + Dir['[A-Z]*']
  s.require_path = '.'
  s.autorequire = 'lazy'
  s.author = "MenTaLguY"
  s.email = "mental@rydia.net"
  s.homepage = "http://moonbase.rydia.net/software/lazy.rb/"
end

