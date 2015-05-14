require 'sv/logger'
require 'sv/error'
require 'sv/job'
require 'securerandom'

module Sv
  class Config
    include Logger

    attr_reader :app_dir

    def initialize(app_dir)
      @app_dir = app_dir
      @instances = {}
      @working_dir = app_dir
      @namespace = SecureRandom.hex(3)
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
      @jobs ||= begin
        load_from_file
        jobs_map.values
      end
    end

    private 

    def jobs_map
      @jobs_map ||= {}
    end

    def instances(instances_map)
      @instances = instances_map
    end

    def job(name, &block)
      name = name.to_sym
      j = jobs_map[name] || Job.new(name)
      j.instance_eval &block
      jobs_map[name] = j
    end

    def working_dir(working_dir)
      @working_dir = working_dir
    end

    def load_from_file
      load_jobs("#{app_dir}/config/jobs.yml", optional: true)
      read_config("#{app_dir}/config/jobs.rb", optional: true)
      read_config("#{app_dir}/config/sv.rb")
      set_instances
      set_working_dir
      set_namespace
    end


    def set_instances
      jobs_map.each do |name, job|
        job.numprocs @instances[name] if @instances.key? name
      end
    end

    def set_working_dir
      jobs_map.values.each do |job|
        job.working_dir || job.working_dir(@working_dir)
      end
    end

    def set_namespace
      jobs_map.each do |name, job|
        job.namespace = @namespace
      end
    end

    def read_config(path, optional: false)
      if not File.readable? path
        raise ::Sv::Error, "config file #{path} missing" if not optional
        return
      end
      instance_eval File.read(path), path
    end

    def load_jobs(path, optional: false)
      if not File.readable? path
        raise ::Sv::Error, "config file #{path} missing" if not optional
        return
      end
      require 'yaml'
      job_definitions = YAML.load_file(path)
      job_definitions.each do |j|
        name = j['name'].to_sym
        job = Job.new(name)
        job.update(j)
        jobs_map[name] = job
      end
    end
  
  end
end
