require 'sv/logger'
module Sv
  class RollingRestart

    include Logger

    def initialize(jobs, api)
      @jobs = jobs
      @api = api
    end

    def run
      init
      @api.reread_config
      stop_unneeded_processes
      add_new_groups
      replace_processes
      remove_old_groups
    end

    def stop_unneeded_processes
      unneeded_processes.each do |x|
        logger.info "#{"-".bold.red} #{x.name}: #{x.group}"
        @api.stop_job x.group, x.name
      end
    end

    def add_new_groups
      @new_groups.each { |g| @api.add_group g }
    end

    def replace_processes
      @new_processes.each do |x|
        #stop older processes with same name
        old = @old_processes.select { |p| p.name == x.name }
        old.each do |o|
          logger.debug "stopping #{o.group}:#{o.name}"
          @api.stop_job o.group, o.name
        end

        if old.empty?
          logger.info  "#{"+".bold.green} #{x.name}: #{x.group}"
        else
          logger.info "#{"\u2219".bold.blue} replacing #{x.name}: -> #{x.group}"
        end
        @api.start_job x.group, x.name
      end
    end

    def remove_old_groups
      @old_groups.each { |g| @api.remove_group g }
    end

    def unneeded_processes
      @old_processes.reject { |p| @new_processes.find {|n| n.name == p.name }}
    end

    def load_old_processes
      @old_processes = @api.jobs
    end

    def load_old_groups
      @old_groups = @old_processes.map { |p| p.group }.uniq
    end

    def load_new_processes
      @new_processes = []
      @jobs.each do |j|
        j.processes.each { |p| @new_processes << p }
      end
      return @new_processes
    end

    def load_new_groups
      @new_groups = @new_processes.map { |p| p.group }.uniq
    end

    def init
      load_new_processes
      load_new_groups
      load_old_processes
      load_old_groups
    end

  end
end
