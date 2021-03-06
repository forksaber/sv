require 'logger'
require 'sv/ext/string'
module Sv
  class CustomLogger < ::Logger

    def initialize(file)
      super(file)
      @level = ::Logger::INFO
    end

    def format_message(severity, timestamp, progname, msg)
      case severity
      when "INFO"
        "#{msg}\n"
      when "ERROR"
        "#{severity.bold.red} #{msg}\n"
      when "WARN"
        "#{severity.downcase.bold.yellow} #{msg}\n"
      else
        "#{severity[0].upcase.bold.blue} #{msg}\n"
      end
    end

  end
end
