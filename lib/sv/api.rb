require 'sv/base'
require 'sv/error'
require 'sv/ext/net_http'
require 'xmlrpc/client'
module Sv
  class Api < ::Sv::Base

    attr_reader :socket_path

    def initialize(socket_path)
      @socket_path = socket_path
    end

    def start_jobs(wait: true)
      output = call "supervisor.startAllProcesses", "wait=#{wait}"
      puts output
    end

    def shutdown
      call "supervisor.shutdown"
    end
  
    def start(job)
      call "supervisor.startProcess", job
    end

    def stop(job)

    end

    def status
      call "supervisor.getAllProcessInfo"
    end

    def errors
      @errors ||= []
    end

    private

    def rpc
      @rpc ||= ::XMLRPC::Client.new(socket_path, "/RPC2")
    end

    def call(*args)
      puts args
      output = rpc.call(*args)
      return output
    rescue XMLRPC::FaultException => e
      raise ::Sv::Error, "error running command #{args[0]}"
    end



  end
end
