require 'net/ssh'
module AntHill
  class SSHConnection < ConnectionPool
    include DRbUndumped
    def closed?(connection)
      return true if connection.closed?
      begin 
        # Hack to check connection isn't dead
        connection.exec!('true') unless connection.busy?
      rescue Net::SSH::Exception, SystemCallError => e
        return true
      end
      return false
    end

    def busy?(connection)
      connection.busy?
    end

    def get_new
      logger.debug "Establishing connection for #{creep.user}@#{creep.host} passwd:#{creep.password}"
      ssh =  Net::SSH.start(creep.host, creep.user, {:password => creep.password, :verbose => (ENV['SSH_DEBUG'] && ENV['SSH_DEBUG'].to_sym) || :fatal })
      ssh.send_global_request("keepalive@openssh.com")
      ssh
    rescue Net::SSH::Exception => ex
      logger.error "There was an exception in method get_new for SSConnection. Details #{ex}:\n#{ex.backtrace}"
      return nil
    rescue SystemCallError => ex
      logger.error "There was an system error in method get_new for SSConnection. Details #{ex}:\n#{ex.backtrace}"
      return nil
    end
    
    def execute(connection, command)
      stdout = ""
      stderr = ""
      connection.exec!(command) do |ch, stream, data|
        stderr << data if stream == :stderr
        stdout << data if stream == :stdout
      end
      [stdout, stderr]
    rescue Net::SSH::Exception => ex
      logger.error "There was an exception in method execute for SSHConnection. Details #{ex}:\n#{ex.backtrace}"
      kill_connection(connection)
      ["", ""]
    rescue SystemCallError => ex
      logger.error "There was an system error in method get_new for SSConnection. Details #{ex}:\n#{ex.backtrace}"
      kill_connection(connection)
      ["", ""]
    end

    def kill_connection(connection)
      connection.shutdown!
    end
  end
end
