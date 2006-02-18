# = lazy/stream.rb -- Even lazy streams in Ruby
#
# Author:: MenTaLguY
#
# Copyright 2005  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'lazy'
require 'singleton'

module Lazy
extend self

class Stream < Promise
  def smap( &block )
    Stream.new { __result__.smap &block }
  end
  def sgrep( re, &block )
    Stream.new { __result__.sgrep( re, &block ) }
  end
  def sselect( &pred )
    Stream.new { __result__.sselect &pred }
  end
  def sreject( &pred )
    Stream.new { __result__.sreject( &pred ) }
  end
  def spartition( &pred )
    [ sselect( &pred ), sreject( &pred ) ]
  end
  def spartition_slow( &pred )
    memoized = smap { |e| [ pred.call e, e ] }
    [ memoized.sselect { |p| p.first }.smap { |p| p.last },
      memoized.sreject { |p| p.first }.smap { |p| p.last } ]
  end
  def szip( *streams )
    Stream.new { __result__.szip( *streams ) }
  end
  def sunzip( n=2 )
    (0...n).map { |i| smap { |tuple| tuple[i] } }
  end
end

# A cell in a lazy stream; here, an actual lazy list should begin with
# a promise for a computation that produces a Lazy::Stream rather than
# a bare Lazy::Stream -- this is the difference between "even" and "odd"
# lazy lists (this library, like Haskell etc., is designed to be used
# with "even" lazy lists).
#
class Cons
  attr_reader :first # the first value in the list
  attr_reader :rest  # a promised computation for the remainder of the list

  def initialize( first, rest )
    @first = first
    @rest = rest
  end

  def empty? ; false ; end

  def each
    head = self
    until head.empty?
      yield head.first
      head = demand head.rest
    end
    self
  end

  def smap( &f ) #:yields: value
    Cons.new( f.call( @first ), @rest.smap &f )
  end

  def sgrep( re, &block )
    tail = @tail.sgrep( re, &block )
    if re === @first
      value = @first
      value = block.call( value ) if block
      Cons.new( value, tail )
    else
      tail
    end
  end

  def sselect( &pred ) #:yields: value
    tail = @tail.sselect( &pred )
    if pred.call( @first )
      Cons.new( @first, tail )
    else
      tail
    end
  end

  def sreject( &pred )
    tail = @tail.sreject( &pred )
    unless pred.call( @first )
      Cons.new( @first, tail )
    else
      tail
    end
  end

  def szip( *heads )
    heads.map! { |head| demand head }
    values = heads.map { |head| head.empty? ? nil : head.first }
    tail = zip_stream( *heads.map { |head|
      head.empty? ? Stream::NULL : head.rest
    } )
    Cons.new( values, tail )
  end
end

class Null
  include Singleton

  def empty? ; true ; end
  def each ; end

  def smap( &f ) ; self ; end

  def szip( *heads ) ; self ; end
end

class Stream
  NULL = Null.instance
end

end

