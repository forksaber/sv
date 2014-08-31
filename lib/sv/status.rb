require 'socket'

module Sv
  class Status
  
    attr_reader :socket_path

    def initialize(socket_path)
      @socket_path = socket_path
    end

    def running?
      s = UNIXSocket.new(socket_path) 
      s.close
      return true
    rescue Errno::ECONNREFUSED, Errno::ENOENT
      return false
    end

    def stopped?
      not running?
    end

    def wait_until_stopped
      loop do
        break if not running?
        sleep 0.1
      end
    end

  end
end
