module AntHill
  class ConnectionPool
    attr_reader :creep
    include DRbUndumped
    def initialize(creep)
      @creep = creep
      @connection_pool = []
    end
    def exec(command)
      conn = get_connection
      if conn
        execute(conn, command)
      else
        logger.error "Couldn't find any free connection or create new one"
      end
    end

    def get_connection
      @connection_pool.delete_if{ |connection| closed?(connection) }
      connection = @connection_pool.find{|c| !c.busy?}
      return connection if connection
      new_conn = get_new
      @connection_pool << new_conn if new_conn
      new_conn
    end

    def destroy
      @connection_pool.each{|connection| kill_connection(connection)}
    end

    def logger
      creep.logger
    end

    def closed?(connection)
      raise "Should be implemented in child class"
    end

    def busy?(connection)
      raise "Should be implemented in child class"
    end

    def kill_connection(connection)
      raise "Should be implemented in child class"
    end
    
    def get_new
      raise "Should be implemented in child class"
    end
    
    def execute(connection, command)
      raise "Should be implemented in child class"
    end

  end
end
