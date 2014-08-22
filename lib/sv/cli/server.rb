require 'sv/server'

module Sv::Cli

  class Server

    attr_reader :app_dir, :argv

    def initialize(app_dir, argv: ARGV)
      @app_dir = app_dir
      @argv = argv
    end

    def run
      command = argv.shift.to_sym
      case command
      when :'print-config'
        server.send :print_config
      when :start, :shutdown, :status
        server.send command
      when :'jobs.start'
        server.send :start_jobs
      else
        raise ::Sv::Error, "no such command #{command}"
      end
    end

    private

    def server
      @server ||= ::Sv::Server.new(app_dir)
    end

  end

end
