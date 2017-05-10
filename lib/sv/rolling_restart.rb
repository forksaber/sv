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

    private

    def init
      load_new_processes
      load_new_groups
      load_old_processes
      load_old_groups
    end

    def stop_unneeded_processes
      unneeded_processes.each do |x|
        logger.info "#{"-".bold.red} #{x.name}: #{x.group}"
        stop_job x, false
      end

      sleep 1.5
      stopping = unneeded_processes.select { |j| j.statename == "STOPPING" }
      stopping.each do |j|
        name = j.name.gsub(/_[0-9]+\z/, "")
        matching_job = @jobs.find { |job| job.name == name }
        kill_cond = !matching_job || matching_job.stopwait_on_rr
        if kill_cond
          kill_job j
        else
          puts "skip kill #{j.group}: #{j.name}"
        end
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
          stop_job o, x.stopwait_on_rr
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
      stopped_states = ["STOPPED", "FATAL", "EXITED"]
      jobs = @api.jobs
      @old_groups.each do |g|
        stopped_count = jobs.select { |j| j.group == g && stopped_states.include?(j.statename) }.size
        all_count = jobs.select { |j| j.group == g }.size
        if stopped_count != all_count
          puts "skip remove_group #{g}: #{all_count - stopped_count} processes running"
          next
        end
        @api.remove_group g
      end
    end

    def unneeded_processes
      @api.jobs.reject { |p| @new_processes.find {|n| n.name == p.name }}
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

    def stop_job(job, wait)
      if wait
        logger.debug "stopping #{job.group}:#{job.name}"
      else
        logger.debug "signaling #{job.group}:#{job.name} to stop"
      end
      @api.stop_job job.group, job.name, wait: wait
    end

    def kill_job(job)
      puts "killing #{job.group}:#{job.name}"
      begin
        Process.kill("KILL", job.pid)
      rescue => e
        puts "warn #{job.pid}: #{e.message}"
      end
    end

  end
end
