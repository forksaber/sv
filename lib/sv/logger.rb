require 'logger'
require 'sv/custom_logger'
module Sv
  module Logger

    def self.logger
      @logger ||= ::Sv::CustomLogger.new(STDOUT)
    end

    def self.stderr
      @stderr ||= ::Logger.new(STDERR)
    end

    def logger
      ::Sv::Logger.logger
    end

    def stderr
      ::Sv::Logger.stderr
    end
  end
end
