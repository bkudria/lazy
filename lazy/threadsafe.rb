# = lazy/threadsafe.rb -- makes promises threadsafe (at the cost of performance)
#
# Author:: MenTaLguY
#
# Copyright 2006  MenTaLguY <mental@rydia.net>
# Copyright (C) 2001  Yukihiro Matsumoto
# Copyright (C) 2000  Network Applied Communication Laboratory, Inc.
# Copyright (C) 2000  Information-technology Promotion Agency, Japan
#
# You may redistribute it and/or modify it under the same terms as Ruby.
#

require 'lazy'
require 'thread'

module Lazy

class Promise
  def __init_lock__ #:nodoc:
    @waiting ||= []
  end

  def __synchronize__ #:nodoc:
    current = Thread.current

    while (Thread.critical = true; @locked)
      if @locked == current
        Thread.critical = false
        DIVERGES.call
      else
        @waiting.push current
        Thread.stop
      end
    end
    @locked = current
    Thread.critical = false

    begin
      yield
    ensure
      Thread.critical = true
      @locked = nil
      begin
        t = @waiting.shift
        t.wakeup if t
      rescue ThreadError
        retry
      end
      Thread.critical = false
      begin
        t.run if t
      rescue ThreadError
      end
    end
  end
end

end

