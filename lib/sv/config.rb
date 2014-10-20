require 'sv/logger'
require 'sv/error'
require 'sv/job'
require 'ostruct'

module Sv
  class Config
    include Logger

    attr_reader :app_dir

    def initialize(app_dir)
      @app_dir = app_dir
      @instances = {}
    end

    def config
      @config ||= begin
        load_from_file
        OpenStruct.new(attributes)
      end
    end

    private 

    def jobs
      @jobs ||= {}
    end

    def instances(instances_map)
      @instances = instances_map
    end

    def job(name, &block)
      name = name.to_sym
      j = jobs[name] || Job.new(name)
      j.instance_eval &block
      jobs[name] = j
    end

    def working_dir(working_dir)
      set :working_dir, working_dir
    end

    def set(key, value)
      attributes.store key, value
    end

    def load_from_file
      load_jobs("#{app_dir}/config/jobs.yml", optional: true)
      read_config("#{app_dir}/config/jobs.rb", optional: true)
      read_config("#{app_dir}/config/sv.rb")
      set_instances
      set_working_dir
    end


    def set_instances
      jobs.each do |name, job|
        job.numprocs @instances[name] if @instances.key? name
      end
    end

    def set_working_dir
      jobs.values.each do |job|
        job.working_dir || job.working_dir(attributes.fetch :working_dir)
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
        jobs[name] = job
      end
    end


    def set_or_get(key, args)
      if args.length == 0
        return attributes.fetch key
      else
        value = args.first
        if block_given?
          value = yield value 
        end
        attributes.store key, value
      end
    end

    def attributes
      @attributes ||= {
        socket_path: "#{app_dir}/tmp/sockets/supervisor.sock",
        pidfile: "#{app_dir}/tmp/pids/supervisor.pid",
        logfile: "#{app_dir}/log/supervisord.log",
        working_dir: app_dir,
        jobs: jobs.values
      }
    end

  end
end
