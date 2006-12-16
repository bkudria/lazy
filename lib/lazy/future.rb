# = lazy/futures.rb -- futures for Ruby
#
# Author:: MenTaLguY
#
# Copyright 2006  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'lazy'

module Lazy

# A promise whose computation runs asynchronously in the background.
#
class Future < Promise
  def initialize( scheduler=Thread, &computation ) #:nodoc:
    task = scheduler.new { computation.call self }
    super() do
      raise DivergenceError if Thread.current == thread
      task.value
    end
  end
end

module Methods
private
  # Schedules a computation to be run asynchronously and returns a promise
  # for its result.  An attempt to force the result of the promise will
  # block until the computation finishes.
  #
  # If +scheduler+ is not specified, the computation is run in a background
  # thread which is joined when the result is forced.  A scheduler should
  # provide a method, new, which takes a block and returns a task
  # object.  The task object should provide a method, value, which awaits
  # completion of the task, returning its result or raising the exception that
  # terminated the task.  The Thread class trivially satisfies this
  # protocol.
  #
  # As with Lazy::Methods#force, this passes the block a promise for its own
  # result.  Use wisely.
  #
  def async( scheduler=Thread, &computation ) #:yields: own_result
    Lazy::Future.new scheduler, &computation
  end 
end

class << self
  public :async
end

end

