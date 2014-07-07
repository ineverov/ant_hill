module AntHill
  # Exception
  class NoFreeConnectionError < Exception; end
  # Base class for storing connections
  class ConnectionPool

    # Attribute readers
    # +creep+:: +Creep+ object
    attr_reader :creep
    include DRbUndumped

    # Initialize
    # +creep+:: creep for which we'll create connections
    def initialize(creep)
      @creep = creep
      @connection_pool = []
    end

    # Execute command on creep
    def exec(command)
      conn = get_connection
      if conn
        begin 
          execute(conn, command)
        rescue Timeout::Error => e
          kill_connection(conn)
          raise e
        end
      else
        logger.error "Couldn't find any free connection or create new one"
        raise NoFreeConnectionError
      end
    end

    # Find free connection
    def get_connection
      @connection_pool.delete_if{ |connection| closed?(connection) }
      connection = @connection_pool.find{|c| !c.busy?}
      return connection if connection
      new_conn = nil
      begin
        Timeout::timeout( 10 ) do
          new_conn = get_new
        end
      rescue Timeout::Error => e
        return nil
      end
      @connection_pool << new_conn if new_conn
      new_conn
    end

    # Close all connections
    def destroy
      @connection_pool.each{|connection| kill_connection(connection)}
    end

    # logger object
    def logger
      creep.logger
    end

    # Check if connection is closed
    # Should be redefined in child class
    # +connection+:: connection to check 
    def closed?(connection)
      raise "Should be implemented in child class"
    end

    # Check if connection is busy
    # Should be redefined in child class
    # +connection+:: connection to check 
    def busy?(connection)
      raise "Should be implemented in child class"
    end

    # Kill connection
    # Should be redefined in child class
    # +connection+:: connection to kill 
    def kill_connection(connection)
      raise "Should be implemented in child class"
    end
    
    # Establish new connection
    # Should be redefined in child class
    def get_new
      raise "Should be implemented in child class"
    end
    
    # Execute command on connection
    # Should be redefined in child class
    # +connection+:: connection where execute command
    # +command+:: cpmmad to execute
    def execute(connection, command)
      raise "Should be implemented in child class"
    end

  end
end
