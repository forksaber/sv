require 'sv/base'
require 'sv/error'
require 'sv/ext/net_http'
require 'xmlrpc/client'
require 'ostruct'

module Sv
  class Api < ::Sv::Base

    attr_reader :socket_path

    def initialize(socket_path)
      @socket_path = socket_path
    end

    def start_jobs(wait: true)
      wait ? start_jobs_in_foreground : start_jobs_in_background
    end

    def shutdown
      call "supervisor.shutdown"
      close_connection
    end
  
    def start_job(group, name)
      call "supervisor.startProcess", "#{group}:#{name}"
    end

    def stop_job(group, name)
      call "supervisor.stopProcess" if not job_stopped?(group, name)
    rescue XMLRPC::FaultException => e
      return true if e.faultString == "NOT_RUNNING"
      raise e
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
      name_width = jobs.map { |j| j.name.size }.max
      template = "%-#{name_width}s  %-10s %-7s %-20s\n"
      printf template, "name", "state", "pid", "uptime"
      puts "-"*(name_width + 10 + 7 + 20 + 2)
      jobs.each do |job|
        logger.debug { require 'pp'; PP.pp job.to_h, out="" ; out }
        printf template, job.name, job.statename, job.pid, uptime(job.start)
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

    def close_connection
      @rpc = nil
    end


    private

    def rpc
      @rpc ||= ::XMLRPC::Client.new(socket_path, "/RPC2")
    end

    def call(*args)
      output = rpc.call(*args)
      return output
    rescue XMLRPC::FaultException => e
      puts
      puts e.message
      raise ::Sv::Error, "error running command #{args[0]}"
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

  end
end
