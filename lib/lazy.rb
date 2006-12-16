# = lazy.rb -- Lazy evaluation in Ruby
#
# Author:: MenTaLguY
#
# Copyright 2005-2006  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'thread'

module Lazy

# Raised when a forced computation diverges (e.g. if it tries to directly
# use its own result)
#
class DivergenceError < Exception
  def initialize( message="Computation diverges" )
    super( message )
  end
end

# Wraps an exception raised by a lazy computation.
#
# The reason we wrap such exceptions in LazyException is that they need to
# be distinguishable from similar exceptions which might normally be raised
# by whatever strict code we happen to be in at the time.
#
class LazyException < DivergenceError
  # the original exception
  attr_reader :reason

  def initialize( reason )
    @reason = reason
    super( "Exception in lazy computation: #{ reason } (#{ reason.class })" )
    set_backtrace( reason.backtrace.dup ) if reason
  end
end

# A promise is just a magic object that springs to life when it is actually
# used for the first time, running the provided block and assuming the
# identity of the resulting object.
#
# This impersonation isn't perfect -- a promise wrapping nil or false will
# still be considered true by Ruby -- but it's good enough for most purposes.
# If you do need to unwrap the result object for some reason (e.g. for truth
# testing or for simple efficiency), you may do so via Kernel.force.
#
# Formally, a promise is a placeholder for the result of a deferred computation.
#
class Promise
  alias __class__ class #:nodoc:
  instance_methods.each { |m| undef_method m unless m =~ /^__/ }

  def initialize( &computation ) #:nodoc:
    @mutex = Mutex.new
    @computation = computation
  end

  # create this once here, rather than creating a proc object for
  # every evaluation
  DIVERGES = lambda { raise DivergenceError.new } #:nodoc:
  def DIVERGES.inspect #:nodoc:
    "DIVERGES"
  end

  def __result__ #:nodoc:
    @mutex.synchronize do
      if @computation
        raise LazyException.new( @exception ) if @exception

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
          raise LazyException.new( @exception )
        end
      end

      @result
    end
  end

  def inspect #:nodoc:
    @mutex.synchronize do
      if @computation
        "#<#{ __class__ } computation=#{ @computation.inspect }>"
      else
        @result.inspect
      end
    end
  end

  def respond_to?( message ) #:nodoc:
    message = message.to_sym
    message == :__result__ or
    message == :inspect or
    __result__.respond_to? message
  end

  def method_missing( *args, &block ) #:nodoc:
    __result__.__send__( *args, &block )
  end
end

module Methods
private

# Used together with Lazy::Methods#force to implement
# lazy evaluation.  It returns a promise to evaluate the provided
# block at a future time.  Evaluation can be forced and the block's
# result obtained via 
#
# Implicit evaluation is also supported: the first message sent to it will
# force evaluation, after which that message and any subsequent messages
# will be forwarded to the result object.
#
# As an aid to circular programming, the block will be passed a promise
# for its own result when it is evaluated.  Be careful not to force
# that promise during the computation, lest the computation diverge.
#
def lazy( &computation ) #:yields: own_result
  Lazy::Promise.new &computation
end

# Forces the result of a promise to be computed (if necessary) and returns
# the bare result object.  Once evaluated, the result of the promise will
# be cached.  Nested promises will be evaluated together, until the first
# non-promise result.
#
# If called on a value that is not a promise, it will simply return it.
#
def force( promise )
  if promise.respond_to? :__result__
    promise.__result__
  else # not really a promise
    promise
  end
end

end

EXPORT_BLACKLIST = [ "EXPORT_BLACKLIST", "Methods" ]

extend Methods
class << self
  public :lazy, :force
end

end

