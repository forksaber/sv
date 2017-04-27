require 'sv/base'
require 'sv/error'
require 'sv/ext/net_http'
require 'xmlrpc/client'
require 'ostruct'

module Sv
  class Api < ::Sv::Base

    attr_reader :socket_path

    def initialize(socket_path)
      @socket_path = File.realdirpath socket_path
    end

    def start_jobs(wait: true)
      wait ? start_jobs_in_foreground : start_jobs_in_background
    end

    def shutdown
      call "supervisor.stopAllProcesses", false
      sleep 2
      stopping = jobs.select { |j| j.statename == "STOPPING" }
      stopping.each do |j|
        puts "killing #{j.group}:#{j.name}"
        Process.kill("KILL", j.pid)
      end
      sleep 1
      call "supervisor.shutdown"
      close_connection
    end
  
    def start_job(group, name)
      call "supervisor.startProcess", "#{group}:#{name}"
    end

    def stop_job(group, name, wait: true)
      return if job_stopped?(group, name)
      ok, output = call_safe "supervisor.stopProcess", "#{group}:#{name}", wait
      if not ok
        msg = "stopping job #{name} failed: #{output.faultString}"
        raise Error, msg if not output.faultString =~ /\ANOT_RUNNING/
      end
    end

    def remove_group(name)
      call "supervisor.stopProcessGroup", name
      call "supervisor.removeProcessGroup", name
    end

    def add_group(name)
      ok, output = call_safe("supervisor.addProcessGroup", name)
      if not ok
        msg = "adding group #{name} failed: #{output.faultString}"
        raise Error, msg if not output.faultString =~ /\AALREADY_ADDED/
      end
    end

    def job_stopped?(group, name)
      job = call "supervisor.getProcessInfo", "#{group}:#{name}"
      job["state"] == 0 ? true : false
    end

    def pid
      call "supervisor.getPID"
    end

    def print_status
      puts "pid #{pid}"
      jobs = self.jobs
      name_width = jobs.map { |j| j.name.size }.max || 20
      template = "%-#{name_width}s  %-10s %-7s %-20s %-50s\n"
      printf template, "name", "state", "pid", "uptime", "dir"
      puts "-"*(name_width + 10 + 7 + 20 + 50 + 2)
      jobs.each do |job|
        logger.debug { require 'pp'; PP.pp job.to_h, out="" ; out }
        dir = (job.statename == "STOPPING" || job.statename == "RUNNING" ) ? job_cwd(job.pid) : "-"
        printf template, job.name, job.statename, job.pid, uptime(job.start), dir
      end
    end

    def start_jobs_in_background
      call "supervisor.startAllProcesses", "wait=false"
    end

    def start_jobs_in_foreground
      jobs.each do |j|
        printf "#{j.name}: starting"
        start_job j.group, j.name
        puts "\r#{j.name}: started "
      end
    end

    def jobs
      jobs_array = call "supervisor.getAllProcessInfo"
      jobs = jobs_array.map { |j| OpenStruct.new(j) }
    end

    def active_groups
      running_states = ["STOPPING", "RUNNING"]
      running_jobs = jobs.select { |j| running_states.include? j.statename }
      running_jobs.map { |j| j.group }.uniq
    end

    def reread_config
      call "supervisor.reloadConfig"
    end

    def close_connection
      @rpc = nil
    end

    def reopen_logs
      Process.kill("USR2", pid)
    rescue => e
      raise Error, "unable to reopen logs"
    end

    def health_check
      jobs = self.jobs
      not_running_jobs = jobs.reject { |j| ["RUNNING", "STARTING"].include? j.statename }
      if not_running_jobs.size > 0
        names = not_running_jobs.map { |j| j.name }
        str = names[0..4].join(", ")
        msg = "jobs not running: #{str}"
        raise Error, msg
      end
      puts "OK"
    end

    private

    def rpc
      @rpc ||= ::XMLRPC::Client.new(socket_path, "/RPC2")
    end

    def call(*args)
      output = rpc.call(*args)
      return output
    rescue XMLRPC::FaultException => e
      puts e.message
      raise ::Sv::Error, "error running command #{args[0]}"
    end

    def call_safe(*args)
      rpc.call2(*args)
    end

    def uptime(started_at)
      return "-" if started_at.to_i == 0
      uptime = (Time.now.to_i - started_at).to_i
      mm, ss = uptime.divmod(60)
      hh, mm = mm.divmod(60)
      dd, hh = hh.divmod(24)
      if dd == 1
        "%d day, %02d::%02d::%02d" % [dd, hh, mm, ss]
      elsif dd > 1
        "%d days, %02d::%02d::%02d" % [dd, hh, mm, ss]
      else
        "%02d::%02d::%02d" % [hh, mm, ss]
      end
    end

    def job_cwd(pid)
      File.readlink "/proc/#{pid}/cwd"
    end

  end
end
