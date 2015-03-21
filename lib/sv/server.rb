require 'sv/config'
require 'sv/api'
require 'sv/supervisor/config'
require 'sv/status'

module Sv
  class Server
   
    attr_reader :app_dir

    def initialize(app_dir)
      @app_dir = app_dir
    end

    def start(auto_start: false, wait: false)
      init_once
      if server_status.running?
        puts "supervisor already running with pid #{api.pid}"
        return
      end
      system "supervisord -c #{supervisor_config.generated_path}"
      puts "Started"
      api.start_jobs(wait: wait) if auto_start
    end

    def stop
      init_once
      if server_status.stopped?
        puts "Stopped"
        return
      end
      api.shutdown
      server_status.wait_until_stopped
      puts "Stopped"
    end

    def restart(auto_start: false, wait: false)
      stop if server_status.running?
      start auto_start: auto_start, wait: wait
    end

    def lol
      supervisor_config.generated_path
      p api.jobs
      puts
      api.reread
      p api.jobs

    end

    def rolling_restart
      if not server_status.running
        start(auto_start: true, wait: true)
        return
      end
      api.rolling_restart
    end

    def start_jobs
      api.start_jobs
      puts api.errors
    end

    def status
     if server_status.running?
       api.print_status
     else
       puts "Stopped"
     end
    end

    def print_config
      puts File.read(supervisor_config.generated_path)
    end

    def required_paths
      paths = [
        "#{app_dir}/tmp/sockets/",
        "#{app_dir}/tmp/pids/",
        "#{app_dir}/log/"
      ]
      paths.each do |path|
        path = Pathname.new(path)
        raise ::Sv::Error, "required path missing #{path}" if not path.exist?
      end
    end

    private 

    def config
      @config ||= ::Sv::Config.new(app_dir)
    end

    def api
      @api ||= ::Sv::Api.new(config.socket_path)
    end

    def server_status
      @server_status ||= ::Sv::Status.new(config.socket_path)
    end
    
    def supervisor_config
      @supervisor_config ||= ::Sv::Supervisor::Config.new(config)
    end

    def init_once
      @init_once ||= begin
        required_paths
        true
      end
    end

  end
end
