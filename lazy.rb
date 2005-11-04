# = lazy.rb -- Lazy evaluation in Ruby
#
# Author:: MenTaLguY
#
# Copyright 2005  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'delegate'

module Lazy #:nodoc: all

class Thunk < SimpleDelegator
  def initialize( &computation )
    @computation = computation
    super self
  end
  def __getobj__
    if @computation
      result = @computation.call( self )
      initialize_methods result
      __setobj__ result
      @computation = nil
    end
    super
  end
  def method_missing(*args, &block)
    __getobj__.send(*args, &block)
  end
  alias __force__ __getobj__
end

end

module Kernel

# The promise() function is used together with force() to implement
# lazy evaluation.  It returns a promise to evaluate the provided
# block at a future time, which can be demanded by force().
#
# The promise can also (usually) be used directly in place of the final
# result object; messages sent to the promise will force evaluation of
# the block (if required) and be forwarded to the result object.
#
def promise( &computation )
  Lazy::Thunk::new &computation
end

# Forces the value of a promise and returns it.  If the promise has not
# been evaluated yet, it will be evaluated and its result remebered
# for future calls to force().
#
# If called on a value that is not a promise, it will simply return it.
#
def force( promise )
  if promise.respond_to? :__force__
    promise.__force__
  else
    promise
  end
end

end
