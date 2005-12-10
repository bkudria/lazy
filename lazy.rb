# = lazy.rb -- Lazy evaluation in Ruby
#
# Author:: MenTaLguY
#
# Copyright 2005  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

module Lazy

# Raised when a demanded computation diverges (e.g. if it tries to demand its
# own result, or raises an exception).
#
# The reason we raise evaluation exceptions wrapped in a DivergenceError
# rather than directly is because they can happen at any time, and need
# to be distinguishable from similar exceptions which could be raised by 
# whatever strict code we happen to be in at the moment the result is
# demanded.
#
class DivergenceError < Exception
  # the exception, if any, that caused the divergence
  attr_reader :reason

  def initialize( reason=nil )
    @reason = reason
    message = "Computation diverges"
    message = "#{ message }: #{ reason } (#{ reason.class })" if reason
    super( message )
    set_backtrace( reason.backtrace.dup ) if reason
  end
end

class Promise #:nodoc: all
  instance_methods.each { |m| undef_method m unless m =~ /^__/ }

  def initialize( &computation )
    @computation = computation
  end

  # create this once here, rather than creating another proc object for
  # every evaluation
  DIVERGES = lambda { raise DivergenceError::new }

  def __result__
    if @computation
      raise DivergenceError::new( @exception ) if @exception

      computation = @computation
      @computation = DIVERGES # trap divergence due to over-eager recursion

      begin
        @result = demand( computation.call( self ) )
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

  def inspect
    if @computation
      "#<Lazy::Promise computation=#{ @computation.inspect }>"
    else
      @result.inspect
    end
  end

  def respond_to?( message )
    message = message.to_sym
    message == :__result__ or
    message == :inspect or
    __result__.respond_to? message
  end

  def method_missing( *args, &block )
    __result__.send( *args, &block )
  end
end

end

module Kernel

# The promise() function is used together with demand() to implement
# lazy evaluation.  It returns a promise to evaluate the provided
# block at a future time.  Evaluation can be demanded and the block's
# result obtained via the demand() function.
#
# Implicit evaluation is also supported: a promise can usually be used
# as a proxy for the result; the first message sent to it will demand
# evaluation, and that message and any subsequent messages will be
# forwarded to the result object.
#
# As an aid to circular programming, the block will be passed a promise
# for its own result when it is evaluated.
#
def promise( &computation ) #:yields: result
  Lazy::Promise::new &computation
end

# Forces the value of a promise and returns it.  If the promise has not
# been evaluated yet, it will be evaluated and its result remebered
# for future calls to demand().  Nested promises will be evaluated until
# a non-promise result is arrived at.
#
# If called on a value that is not a promise, it will simply return it.
#
def demand( promise )
  if promise.respond_to? :__result__
    promise.__result__
  else # not really a promise
    promise
  end
end
alias force demand

end
