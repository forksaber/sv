require 'sv/server'

module Sv::Cli

  class Server

    attr_reader :app_dir, :argv

    def initialize(app_dir, argv: ARGV)
      @app_dir = app_dir
      @argv = argv
    end

    def run
      opts.parse!(argv)
      command = argv.shift.to_sym
      case command
      when :start, :restart
        server.send command, auto_start: options[:auto_start], wait: options[:wait]
      when :'print-config'
        server.send :print_config
      when :stop, :status
        server.send command
      else
        raise ::Sv::Error, "no such command #{command}"
      end
    end

    private

    def server
      @server ||= ::Sv::Server.new(app_dir)
    end

    def opts
      @opts ||= OptionParser.new do |opts| 
        opts.on("-a", "--auto-start" , "auto start jobs") do
          options[:auto_start] = true
        end 

        opts.on("-w", "--wait" , "wait for jobs to start successfully") do
          options[:wait] = true
        end

        opts.on_tail("-h", "--help", "Show this message") do 
          puts opts
          exit
        end
      end
    end

    def options
      @options ||= {}
    end

  end

end
