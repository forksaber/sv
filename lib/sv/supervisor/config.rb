require 'erb'
require 'ostruct'
require 'sv/logger'

module Sv::Supervisor
  class Config

    include ::Sv::Logger
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def path
      "#{config.app_dir}/tmp/supervisor.conf"
    end

    def generated_path
      generate_once
      path
    end

    def generate_config_file
      erb = ERB.new(File.read(template), nil, '-')
      File.open(path, 'w') do |f|
        f.write erb.result(binding)
      end 
    rescue => e
      raise ::Sv::Error, "unable to generate supervisor config"
    end

    def generate_once
      return if @config_generated
      generate_config_file
      @config_generated = true
    end

    def template
      "#{__dir__}/../templates/supervisor.conf.erb"
    end

    def rendered_jobs
      jobs = config.jobs
      jobs.inject("")  do |str, job|
        render = job.render 
        str << render if render
        str
      end
    end

    def binding
      opts = OpenStruct.new
      opts.socket_path = config.socket_path
      opts.pidfile = config.pidfile
      opts.logfile = config.logfile
      opts.rendered_jobs = rendered_jobs
      opts.instance_eval { binding }
    end

  end
end
