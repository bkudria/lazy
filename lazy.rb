# = lazy.rb -- Lazy evaluation in Ruby
#
# Author:: MenTaLguY
#
# Copyright 2005  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

module Lazy

# Raised when a forced computation diverges (e.g. if it tries to force its
# own result, or raises an exception).
#
# The reason we raise evaluation exceptions wrapped in a DivergenceError
# rather than directly is because they can happen at any time, and need
# to be distinguishable from similar exceptions which could be raised by 
# whatever strict code happens to force evaluation of a promise.
#
class DivergenceError < Exception
  # the exception, if any, that caused the divergence
  attr_reader :reason

  def initialize( reason=nil )
    @reason = reason
    message = "Computation diverges"
    message = "#{ message }: #{ reason } (#{ reason.class })" if reason
    super( message )
    set_backtrace( reason.backtrace ) if reason
  end
end

class Thunk #:nodoc: all
  instance_methods.each { |m| undef_method m unless m =~ /^__/ }

  def initialize( &computation )
    @computation = computation
  end

  # create this once here, rather than creating another proc object for
  # every evaluation
  DIVERGES = lambda { raise DivergenceError::new }

  def __force__
    if @computation
      raise DivergenceError::new( @exception ) if @exception

      computation = @computation
      @computation = DIVERGES # trap divergence due to over-eager recursion

      begin
        @result = force( computation.call( self ) )
        @computation = nil
      rescue DivergenceError
        raise
      rescue Exception => exception
        # handle exceptions
        @exception = exception
        raise DivergenceError::new( @exception )
      end
    end

    @result
  end

  def method_missing( *args, &block )
    __force__.send( *args, &block )
  end

  def respond_to?( message )
    message = message.to_sym
    message == :__force__ or __force__.respond_to? message
  end
end

class Cons
  attr_reader :first
  attr_reader :rest

  def initialize(first, rest)
    @first = first
    @rest = rest
  end

  class << self
    alias strict_new new

    def new( &constructor )
      if constructor
        promise {
          first, rest = constructor.call
          strict_new( first, rest )
        }
      else
        nil
      end
    end
  end

  def to_lazy_stream
    Stream::new self
  end
end

def generate( &generator )
  promise { generator.call( generate( &generator ) ) }
end
module_function :generate

def generate_infinite_list( &generator )
  generate { |rest| Cons::strict_new( generator.call, rest ) }
end
module_function :generate_infinite_list

def map_list( head, &f )
  promise {
    head = force head
    if head
      Cons::strict_new( f.call( head.first ), map_list( head.rest, &f ) )
    else
      nil
    end
  }
end
module_function :map_list

def select_list( head, &pred )
  promise {
    head = force head
    if head
      value = head.first
      rest = select_list( head.rest, &pred )
      if pred.call value
        Cons::strict_new( value, rest )
      else
        rest
      end
    else
      nil
    end
  }
end
module_function :select_list

def grep_list( head, re, &block )
  promise {
    head = force head
    if head
      value = head.first
      rest = grep_list( head, re, &block )
      if re === value
        value = block.call value if block
        Cons::strict_new( value, rest )
      else
        rest
      end
    else
      nil
    end
  }
end
module_function :grep_list

def reject_list( head, &pred )
  select_list( head ) { |value| !pred.call( value ) }
end
module_function :reject_list

def partition_list( head, &pred )
  [ select_list( head, &pred ), reject_list( head, &pred ) ]
end
module_function :partition_list

def partition_list_slow( head, &pred )
  cached_head = map_list( head ) { |value| [ pred.call( value ), value ] }
  true_head = map_list( select_list( cached_head ) { |pair| pair[0] } ) {
    pair[1]
  }
  false_head = map_list( reject_list( cached_head ) { |pair| pair[0] } ) {
    pair[1]
  }
  [ true_head, false_head ]
end
module_function :partition_list_slow

def zip_list( *heads )
  promise {
    heads.map! { |head| force head }
    if heads[0]
      values = heads.map { |head| head ? head.first : nil }
      rest = zip_list( *heads.map { |head| head ? head.rest : nil } )
      Cons::strict_new( values, rest )
    else
      nil
    end
  }
end
module_function :zip_list

def unzip_list( head, n=2 )
  (0...n).map { |i| map_list( head ) { |tuple| tuple[i] } }
end
module_function :unzip_list

class Stream
  include Enumerable

  attr_reader :head

  def initialize( head )
    @head = head
  end

  def Stream.generate( &generator )
    Stream::new Lazy::generate( &generator )
  end

  def Stream.generate_infinite( &generator )
    Stream::new Lazy::generate_infinite_list( &generator )
  end

  def each
    while @head
      yield @head.first
      @head = @head.rest
    end
  end

  def empty? ; @head.nil? ; end

  def sgrep( re, &block )
    Stream::new( Lazy::grep_list( @head, re, &block ) )
  end

  def smap( &f )
    Stream::new( Lazy::map_list( @head, &f ) )
  end
  alias scollect smap

  def sselect( &pred )
    Stream::new( Lazy::select_list( @head, &pred ) ) 
  end
  alias sfind_all sselect

  def sreject( &pred )
    Stream::new( Lazy::reject_list( @head, &pred ) )
  end

  def spartition( &pred )
    true_head, false_head = Lazy::partition_list( @head, &pred )
    [ Stream::new( true_head ), Stream::new( false_head ) ]
  end

  def spartition_slow( &pred )
    true_head, false_head = Lazy::partition_list_slow( @head, &pred )
    [ Stream::new( true_head ), Stream::new( false_head ) ]
  end

  def szip( *streams )
    heads = streams.map { |s| s.to_lazy_stream.head }
    Stream::new Lazy::zip_list( @head, *heads )
  end

  def sunzip( n=2 )
    Lazy::unzip_list( @head, n ).map { |head| Stream::new head }
  end

  def to_lazy_stream ; self ; end
end

end

class NilClass
  def to_lazy_stream ; Lazy::Stream::new nil ; end
end

class Array
  def to_lazy_stream
    promise {
      reverse.inject( nil ) { |head, obj|
        Lazy::Cons::strict_new( obj, head )
      }
    }
  end
end

module Kernel

# The promise() function is used together with force() to implement
# lazy evaluation.  It returns a promise to evaluate the provided
# block at a future time.  Evaluation can be forced and the block's
# result obtained via the force() function.
#
# Implicit evaluation is also supported: a promise can usually be used
# as a proxy for the result; the first message sent to it will force
# evaluation, and that message and any subsequent messages will be
# forwarded to the result object.
#
# As an aid to circular programming, the block will be passed a promise
# for its own result when it is evaluated.
#
def promise( &computation )
  Lazy::Thunk::new &computation
end

# Forces the value of a promise and returns it.  If the promise has not
# been evaluated yet, it will be evaluated and its result remebered
# for future calls to force().  Nested promises will be evaluated until
# a non-promise result is arrived at.
#
# If called on a value that is not a promise, it will simply return it.
#
def force( promise )
  if promise.respond_to? :__force__
    promise.__force__
  else # not really a promise
    promise
  end
end

end
