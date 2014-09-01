require 'sv/logger'
require 'ostruct'
module Sv
  class Job
    include Logger

    attr_accessor :num_instances
    attr_accessor :command, :working_dir

    def initialize(attrs)
      update(attrs)
    end

    def name
      get :name
    end

    def attributes
      @attributes ||= {
        name: nil,
        command: nil,
        working_dir: nil,
        env: "",
        numprocs: 0,
        autorestart: true,
        startsecs: 1,
        startretries: 3,
        stopsignal: :TERM,
        stopwaitsecs: 10,
        killasgroup: true,
        redirect_stderr: true,
        stdout_logfile: "/dev/null",
        stderr_logfile: "/dev/null"
      }
    end

    def instances=(numprocs)
      if numprocs.respond_to? :to_i
        set :numprocs, numprocs.to_i
      else
        logger.warn "ignoring numprocs value #{numprocs}"
      end
    end

    def working_dir=(working_dir)
      set :working_dir, working_dir
    end

    def update(attrs)
      attrs.each do |key ,value|
        set key, value
      end
    end

    def merge_env(env_str)
      return unless env_str.is_a? String
      new_env = get :env
      new_env << ", #{env_str}"
      set :env, new_env
    end

    def template
      @template ||= Pathname.new("#{__dir__}/templates/job.erb")
    end
  
    def render
      return if not attributes.values.all?
      return if attributes[:numprocs] < 1
      File.open(template) do |f|
        erb = ERB.new(f.read, nil, '-')
        erb.result(binding)
      end
    end

    def binding
      attrs = OpenStruct.new(attributes)
      attrs.instance_eval { binding }
    end

    def set(key, value)
      sym = key.to_sym
      attributes.store sym, value if attributes.key? sym
    end

    def get(key)
      attributes.fetch key
    end

  end
end

