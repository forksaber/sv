require 'sv/logger'
module Sv
  class Base
    include ::Sv::Logger

    def process_running?
      return false if pid <= 0
      Process.getpgid pid
      return true
    rescue Errno::ESRCH
      return false
    end

  end
end
