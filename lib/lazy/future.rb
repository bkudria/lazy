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
    thread = Thread.new { computation.call self }
    super() do
      raise DivergenceError if Thread.current == thread
      thread.value
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

