require 'net/ssh'
module AntHill
  # Child of ConnectionPool
  class SSHConnection < ConnectionPool
    include DRbUndumped

    # Check if SSH connection is closed
    # +connection+:: SSH connection to check
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

    # Check if SSH connection is busy
    # +connection+:: SSH connection to check
    def busy?(connection)
      connection.busy?
    end

    # Get new SSH connection 
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
    
    # Execute command on SSH connection
    # +connection+:: SSH connection
    # +command+:: command to execute
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
      raise NoFreeConnectionError
    rescue SystemCallError => ex
      logger.error "There was an system error in method get_new for SSConnection. Details #{ex}:\n#{ex.backtrace}"
      kill_connection(connection)
      raise NoFreeConnectionError
    end

    # Kill SSH connection
    # +connection+:: SSH connection
    def kill_connection(connection)
      connection.shutdown!
    end
  end
end
