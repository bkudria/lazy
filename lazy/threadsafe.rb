# = lazy/threadsafe.rb -- makes promises threadsafe (at the cost of performance)
#
# Author:: MenTaLguY
#
# Copyright 2006  MenTaLguY <mental@rydia.net>
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'lazy'

module Lazy

class Promise
  def __synchronize__ #:nodoc:
    current = Thread.current

    Thread.critical = true
    unless @computation
      # fast path for evaluated thunks
      Thread.critical = false
      yield
    else
      if @owner == current
        Thread.critical = false
        raise DivergenceError.new
      end 
      while @owner # spinlock
        Thread.critical = false
        Thread.pass
        Thread.critical = true
      end
      @owner = current
      Thread.critical = false

      begin
        yield
      ensure
        @owner = nil
      end
    end
  end
end

end

