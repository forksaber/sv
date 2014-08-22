require 'yaml'
require 'sv/base'
require 'sv/job'

module Sv
  class Config < Base

    attr_reader :app_dir

    def initialize(app_dir)
      @app_dir = app_dir
    end

    def to_h
      config
    end

    def config
      @config ||= {
        app_dir: app_dir,
        socket_path: "#{app_dir}/tmp/sockets/supervisor.sock",
        pidfile: "#{app_dir}/tmp/pids/supervisor.pid",
        logfile: "#{app_dir}/log/supervisord.log",
        jobs: jobs 
      }
    end

    def sv_config
      @sv_config ||= load_config(config_path)
    end

    def global_env
      sv_config['env'] || {}
    end

    def jobs
      return @jobs if @jobs
      @jobs = []
      job_definitions.each do |job_hash|
        next if not job_hash.is_a? Hash
        name = job_hash['name']
        job = Job.new(job_hash)
        job.instances = num_instances(name)
        job.working_dir = working_dir
        job.merge_env global_env
        @jobs << job
      end
      @jobs
    end


    def load_config(path)
      path = Pathname.new(path)
      if not path.readable?
        logger.debug "config path doesn't exist => #{path}"
        return {}
      end
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
