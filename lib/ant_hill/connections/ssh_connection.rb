require 'net/ssh'
module AntHill
  class SSHConnection < ConnectionPool
    include DRbUndumped
    def closed?(connection)
      connection.closed?
    end

    def busy?(connection)
      connection.busy?
    end

    def get_new
      logger.debug "Establishing connection for #{creep.user}@#{creep.host} passwd:#{creep.password}"
      ssh =  Net::SSH.start(creep.host, creep.user, {:password => creep.password, :verbose => (ENV['SSH_DEBUG'] && ENV['SSH_DEBUG'].to_sym) || :fatal })
      ssh.send_global_request("keepalive@openssh.com")
      ssh
    end
    
    def execute(connection, command)
      stdout = ""
      stderr = ""
      connection.exec!(command) do |ch, stream, data|
        stderr << data if stream == :stderr
        stdout << data if stream == :stdout
      end
      [stdout, stderr]
    end

    def kill_connection(connection)
      connection.shutdown!
    end
  end
end
