module Sv
  class Job

    attr_reader :name
    attr_writer :working_dir, :namespace

    def initialize(name)
      set :name, name
    end

    def name
      attributes.fetch :name
    end

    def group
      @namespace ? "#{name}.#{@namespace}" : name
    end

    def command(*args)
      set_or_get :command, args
    end

    def working_dir(*args)
      set_or_get :working_dir, args
    end

    def env(*args)
      set_or_get :env, args
    end
    
    def numprocs(*args)
      set_or_get :numprocs, args do |v|
        v.to_i
      end
    end

    def autorestart(*args)
      set_or_get :autorestart, args
    end

    def startsecs(*args)
      set_or_get :startsecs, args
    end

    def startretries(*args)
      set_or_get :startretries, args
    end

    def stopsignal(*args)
      set_or_get :stopsignal, args
    end

    def stopwaitsecs(*args)
      set_or_get :stopwaitsecs, args
    end

    def killasgroup(*args)
      set_or_get :killasgroup, args
    end

    def redirect_stderr(*args)
      set_or_get :redirect_stderr, args
    end

    def stdout_logfile(*args)
      set_or_get :stdout_logfile, args
    end

    def stderr_logfile(*args)
      set_or_get :stderr_logfile, args
    end

    def update(attrs)
      attrs.each do |key ,value|
        set key, value
      end 
    end

    def render
      return if not attributes.values.all?
      return if attributes[:numprocs] < 1
      File.open(template) do |f|
        erb = ERB.new(f.read, nil, '<>')
        erb.result(binding)
      end
    end

    def processes
      processes = []
      s = Struct.new(:name, :group)
      numprocs.times do |i|
        process = s.new
        process.name = "#{name}_#{i.to_s.rjust(2,"0")}"
        process.group = group
        processes << process
      end
      processes
    end

    private

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
        stderr_logfile: nil
      }
    end

    def set_or_get(key, args)
      key = key.to_sym
      if args.length == 0
        return attributes.fetch key
      else
        value = args.first
        if block_given?
          value = yield value 
        end
        set key, value
      end
    end

    def set(key, value)
      key = key.to_sym
      if attributes.key? key
        attributes.store key, value
      else
        raise "no such key #{key}"
      end
    end

    def template
      @template ||= Pathname.new("#{__dir__}/templates/job.erb")
    end

    def binding
      attrs = OpenStruct.new(attributes)
      attrs.group = group
      attrs.instance_eval { binding }
    end
  
  end
end

