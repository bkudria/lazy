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
    if message == :__force__
      true
    else
      __force__.respond_to? message
    end
  end
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
