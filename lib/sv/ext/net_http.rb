require 'net/http'
require 'pathname'

module Net
  class HTTP
    alias_method :orig_connect, :connect

    def connect
      path = Pathname.new(address)
      if path.exist?
        @socket = Net::BufferedIO.new UNIXSocket.new address
        on_connect
      else
        orig_connect
      end
    end

  end
end
