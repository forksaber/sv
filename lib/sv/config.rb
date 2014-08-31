require 'sv/logger'
require 'sv/job'

module Sv
  class Config
    include Logger

    attr_reader :app_dir

    def initialize(app_dir)
      @app_dir = app_dir
    end

    def socket_path
      @socket_path ||= "#{app_dir}/tmp/sockets/supervisor.sock"
    end

    def pidfile
      @pidfile ||= "#{app_dir}/tmp/pids/supervisor.pid"
    end

    def logfile
      @logfile ||= "#{app_dir}/log/supervisord.log"
    end

    def jobs
      @jobs ||= jobs_array
    end

    private 

    def sv_config
      @sv_config ||= load_config(config_path)
    end

    def global_env
      sv_config['env'] || {}
    end

    def jobs_array
      jobs = []
      job_definitions.each do |job_hash|
        next if not job_hash.is_a? Hash
        name = job_hash['name']
        job = Job.new(job_hash)
        job.instances = num_instances(name)
        job.working_dir = working_dir || app_dir
        job.merge_env global_env
        jobs << job
      end
      jobs
    end

    def load_config(path)
      path = Pathname.new(path)
      if not path.readable?
        logger.debug "config path doesn't exist => #{path}"
        return {}
      end
      require 'yaml'
      File.open path do |f|
        YAML.load f.read
      end
    rescue => e
      raise ::Sv::Error, "error loading config file #{path}"
    end

    def job_definitions
      load_config(jobs_yml_path)
    end

    def num_instances(job_name)
      instances[job_name]
    end

    def config_path
      "#{app_dir}/config/sv.yml"
    end

    def jobs_yml_path
      "#{app_dir}/config/jobs.yml"
    end

    def instances
      @instances ||= ( sv_config['instances'] || {} )
    end

    def working_dir
      sv_config['working_dir']
    end

  end
end
