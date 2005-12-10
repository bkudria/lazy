# = lazy/stream.rb -- Even lazy streams in Ruby
#
# Author:: MenTaLguY
#
# Copyright 2005  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'lazy'

module Lazy

# A cell in a lazy stream; here, an actual lazy list should begin with
# a promise for a computation that produces a cell (or nil) rather than
# a bare cell -- this is the difference between "even" and "odd" lazy lists
# (this library, like Haskell etc., is designed to be used with "even"
# lazy lists).
#
class Cons
  attr_reader :first # the first value in the list
  attr_reader :rest  # a promised computation for the remainder of the list

  def initialize(first, rest) #:notnew:
    @first = first
    @rest = rest
  end

  class << self
    # Creates a bare cell rather than a promise for one.  Useful as a minor
    # optimization in cases where there is guaranteed to be an enclosing
    # promise.
    alias strict_new new

    # Creates a promise for a cell; the promised computation is given
    # in the form of a block that produces either a [first, rest]
    # pair or nil.  'first' may be any sort of value, while 'rest' should
    # be a promise for the remainder of the stream (or nil).
    def new( &constructor ) #:yields:
      if constructor
        promise {
          pair = constructor.call
          if pair
            strict_new( *pair )
          else
            nil
          end
        }
      else
        nil
      end
    end
  end

end

# Constructs a cell in a lazy stream using the given block.  The block
# should return a [first, rest] pair.  A wrapper around Lazy::Cons.new
#
# cons_stream is sufficient to generate streams in a purely functional
# fashion; for example:
#
#  def integers_from( n=0 )
#    Lazy.cons_stream { [ n, integers_from( n + 1 ) ] }
#  end
#
# and:
#
#  def fibs( a=1, b=0 )
#    Lazy.cons_stream do
#      sum = a + b
#      [ sum, fibs(b, sum) ]
#    end
#  end
#
# Two functions, Lazy.generate_stream and Lazy.generate_infinite_stream, are
# provided for generating streams in a more imperative fashion.
#
# See also Lazy.generate_stream, Lazy.generate_infinite_stream, and
# Lazy::Cons.new
#
def cons_stream( &computation ) ; Cons.new( &computation ) ; end #:yields:
module_function :cons_stream

# Implements iteration in terms of lazy evaluation; superficially
# similar to promise, except that it passes the block a promise for
# the result of its next iteration, rather than a promise for the
# result of the current call to the block.
#
# This is icky and relies on side-effects to do anything useful,
# but it is a concession to doing things somewhat idiomatically in Ruby.
#
def iterate( &block ) #:yields: next_result
  promise { block.call( iterate( &block ) ) }
end
module_function :iterate

#
# Lazy.generate_stream can be used to build lazy streams.  Its block is
# passed a promise for the remainder of the stream, and the result
# of the block is interpreted in the same fashion as Lazy.cons_stream's.
#
#  Lazy.generate_stream do |tail|
#    if termination_condition
#      nil
#    else
#      result = something
#      [ result, tail ]
#    end
#  end
#
# For generating infinite streams, the convenience wrapper
# Lazy.generate_infinite_stream # is provided.
#
# An unfold for lazy streams could be written in terms of it:
#
#  def unfold( p, f, g, x )
#    Lazy.generate_stream do |tail|
#      if p x
#        nil
#      else
#        value = f.call( x )
#        x = g.call( x )
#        [ value, tail ]
#      end
#    end
#  end
#
# Although the purely functional definition is probably more elegant:
#
#  def unfold( p, f, g, x )
#    Lazy.cons_stream do
#      if p x
#        nil
#      else
#        [ f.call( x ), unfold( p, f, g, g.call( x ) ) ]
#      end
#    end
#  end
#
# See also Lazy.cons_stream Lazy.generate_infinite_stream
#
def generate_stream( &generator ) #:yields: tail
  stream_cons { generator.call( generate_stream( &generator ) ) }
end
module_function :generate_stream

# Constructs an infinite lazy stream, where each value in the stream
# is produced by a call to the given block.  It is a wrapper around
# Lazy.iterate.
#
# For example, a stream producing the Fibonacci sequence can be
# constructed as follows:
#
#  state = [ 1, 0 ]
#  Lazy.generate_infinite_stream do 
#    value = state[0] + state[1]
#    state[0] = state[1]
#    state[1] = value
#    value
#  end
#
# See also Lazy.generate_stream
#
def generate_infinite_stream( &proc ) #:yields:
  iterate { |tail| Cons.strict_new( proc.call, tail ) }
end
module_function :generate_infinite_stream

# Maps one stream to another; each value in the result stream is the result
# of calling the given block on each value from the original stream. 
def map_stream( head, &f ) #:yields: value
  promise {
    head = demand head
    if head
      Cons.strict_new( f.call( head.first ), map_stream( head.rest, &f ) )
    else
      nil
    end
  }
end
module_function :map_stream

# Produces a stream including only those values from the source stream
# for which the predicate is true.  Lazy.reject_stream is its opposite.
#
# See also Lazy.reject_stream
#
def select_stream( head, &pred ) #:yields: value
  promise {
    head = demand head
    if head
      value = head.first
      tail = select_stream( head.rest, &pred )
      if pred.call value
        Cons.strict_new( value, tail )
      else
        tail
      end
    else
      nil
    end
  }
end
module_function :select_stream

# Like Enumerable#grep.
def grep_stream( head, re, &block ) #:yields: value
  promise {
    head = demand head
    if head
      value = head.first
      tail = grep_stream( head, re, &block )
      if re === value
        value = block.call value if block
        Cons.strict_new( value, tail )
      else
        tail
      end
    else
      nil
    end
  }
end
module_function :grep_stream

# Produces a stream which omits the values from the source stream for
# which the given predicate is true.
def reject_stream( head, &pred ) #:yields: value
  select_stream( head ) { |value| !pred.call( value ) }
end
module_function :reject_stream

# Partitions a stream into two streams, based on the given predicate.
# The predicate will be called twice for each value (once per result
# stream).  If you only want the predicate to be called once for each
# value, use Lazy.partition_stream_slow instead.
#
# See also Lazy.partition_stream_slow
def partition_stream( head, &pred ) #:yields: value
  [ select_stream( head, &pred ), reject_stream( head, &pred ) ]
end
module_function :partition_stream

# Partitions a stream into two streams, based on the given predicate.
# The predicate is only computed once for each value, but this is
# otherwise slower than Lazy.partition_stream.
#
# Depending on how you look at it, the 'slow' may indicate either
# that this version of Lazy.partition_stream is itself slower,
# or that it is better for use with predicates which are themselves
# very slow.
#
# See also Lazy.partition_stream
def partition_stream_slow( head, &pred ) #:yields: value
  cached_head = map_stream( head ) { |value| [ pred.call( value ), value ] }
  true_head = map_stream( select_stream( cached_head ) { |pair| pair[0] } ) {
    pair[1]
  }
  false_head = map_stream( reject_stream( cached_head ) { |pair| pair[0] } ) {
    pair[1]
  }
  [ true_head, false_head ]
end
module_function :partition_stream_slow

# Zips n streams into a single stream of n-tuples.
def zip_stream( *heads )
  promise {
    heads.map! { |head| demand head }
    if heads[0]
      values = heads.map { |head| head ? head.first : nil }
      tail = zip_stream( *heads.map { |head| head ? head.rest : nil } )
      Cons.strict_new( values, tail )
    else
      nil
    end
  }
end
module_function :zip_stream

# Unzips a stream of n-tuples into an Array of n streams.
def unzip_stream( head, n=2 )
  (0...n).map { |i| map_stream( head ) { |tuple| tuple[i] } }
end
module_function :unzip_stream

# Lazy::Stream provides an Enumerable interface for lazy streams.
#
class Stream
  include Enumerable

  # The head of the stream.
  attr_accessor :head

  # Creates Lazy::Stream with the given head.
  #
  def initialize( head )
    @head = head
  end

  # Generates a stream using the given block
  #
  # See Lazy.generate_stream
  #
  def Stream.generate( &generator ) #:yields: next_result
    Stream.new Lazy.generate( &generator )
  end

  # Creates an infinite stream where each computation 
  # is a call to the given block.
  #
  # See Lazy.generate_infinite
  #
  def Stream.generate_infinite( &generator ) #:yields:
    Stream.new Lazy.generate_infinite_stream( &generator )
  end

  # Implements Enumerable#each.
  #
  def each( &block ) #:yields: value
    dup.each_consume( &block )
    self
  end

  # Like Lazy::Stream#each, but advances Lazy::Stream's head reference
  # with each iteration, "consuming" it.
  #
  def each_consume #:yields: value
    @head = demand @head
    while @head
      value = @head.first
      @head = @head.rest
      yield value
      @head = demand @head
    end
    self
  end

  # Returns true if there are no values left in this stream; false otherwise.
  def empty? ; @head.nil? ; end

  # Similar to Enumerable#grep, except it produces a Lazy::Stream
  # rather than an Array.
  #
  # See Enumerable#grep and Lazy.grep_stream
  #
  def sgrep( re, &block ) #:yields: value
    Stream.new( Lazy.grep_stream( @head, re, &block ) )
  end

  # Similar to Enumerable#map, except it produces a Lazy::Stream
  # rather than an Array.
  #
  # See Enumerable#map and Lazy.map_stream
  #
  def smap( &f ) #:yeilds: value
    Stream.new( Lazy.map_stream( @head, &f ) )
  end
  alias scollect smap

  # Similar to Enumerable#select, except it produces a Lazy::Stream
  # rather than an Array.
  #
  # See Enumerable#select and Lazy.select_stream
  #
  def sselect( &pred ) #:yields: value
    Stream.new( Lazy.select_stream( @head, &pred ) ) 
  end
  alias sfind_all sselect

  # Similar to Enumerable#reject, except it produces a Lazy::Stream
  # rather than an Array.
  #
  # See Enumerable#reject and Lazy.reject_stream
  #
  def sreject( &pred ) #:yields: value
    Stream.new( Lazy.reject_stream( @head, &pred ) )
  end

  # Similar to Enumerable#partition, except it produces a Lazy::Stream
  # rather than an Array.  Returns a pair of streams.
  #
  # See Enumerable#partition and Lazy.partition_stream
  #
  def spartition( &pred ) #:yields: value
    true_head, false_head = Lazy.partition_stream( @head, &pred )
    [ Stream.new( true_head ), Stream.new( false_head ) ]
  end

  # Similar to Enumerable#partition, except it produces a Lazy::Stream
  # rather than an Array.  Evaluates the predicate only once for each
  # value in the stream, but is otherwise slower than Stream#spartition.
  #
  # See Enumerable#partition and Lazy.partition_stream_slow
  #
  def spartition_slow( &pred ) #:yields: value
    true_head, false_head = Lazy.partition_stream_slow( @head, &pred )
    [ Stream.new( true_head ), Stream.new( false_head ) ]
  end

  # Similar to Enumerable#zip, except it produces a Lazy::Stream rather
  # than an Array.  Zips n streams (including this one) into a single
  # stream of n-tuples.
  # 
  # See Enumerable#zip and Lazy.zip_stream
  #
  def szip( *streams )
    heads = streams.map { |s| s.head }
    Stream.new Lazy.zip_stream( @head, *heads )
  end

  # Unzips a stream of n-tuples into an Array of n streams.
  #
  # See Lazy.unzip_stream
  #
  def sunzip( n=2 )
    Lazy.unzip_stream( @head, n ).map { |head| Stream.new head }
  end
end

end

