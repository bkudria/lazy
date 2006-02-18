# = lazy/futures.rb -- futures for Ruby
#
# Author:: MenTaLguY
#
# Copyright 2006  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'lazy/threadsafe'

module Lazy

class Future < Promise
  def initialize( &computation ) #:nodoc:
    result = nil
    exception = nil

    thread = Thread.new do
      begin
        result = computation.call( self )
      rescue Exception => exception
      end
    end

    super() do
      raise DivergenceError.new if Thread.current == thread
      thread.join
      raise exception if exception
      result
    end
  end
end

end

module Kernel

# Schedules a computation to be run asynchronously in a background thread
# and returns a promise for its result.  An attempt to demand the result of
# the promise will block until the computation finishes.
#
# As with Kernel.promise, this passes the block a promise for its own result.
# Use wisely.
#
def future( &computation ) #:yields: result
  Lazy::Future.new &computation
end 

end

