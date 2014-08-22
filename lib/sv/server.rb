require 'sv/config'
require 'sv/api'
require 'sv/supervisor/config'

module Sv
  class Server
   
    attr_reader :app_dir

    def initialize(app_dir)
      @app_dir = app_dir
    end

    def start
      system "supervisord -c #{supervisor_config.generated_path}"
    end

    def shutdown
      api.shutdown
    end

    def start_jobs
      api.start_jobs
      puts api.errors
    end

    def status
      puts api.status
    end

    def print_config
#      pp config.to_h
      puts File.read(supervisor_config.generated_path)
    end

    private 

    def config
      @config ||= ::Sv::Config.new(app_dir).to_h
    end

    def api
      @api ||= ::Sv::Api.new(config[:socket_path])
    end

    def supervisor_config
      @supervisor_config ||= ::Sv::Supervisor::Config.new(config)
    end


  end
end
