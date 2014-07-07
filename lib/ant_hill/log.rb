module AntHill
  # Log class
  class Log
    include DRbUndumped
    # Singleton class
    class << self
      @@loggers = {}
      # Return logger for specified name
      def logger_for(name, config = Configuration.config)
        return @@loggers[name] if @@loggers[name]
        verbose = config.log_level
        path = config.log_dir
        FileUtils.mkdir_p path unless File.exists?(path)
        logger = Logger.new(path+"/#{name}.log", (config.log_num_old_files) || 5, (config.log_size || 50*1024*1024) )
        logger.level = level(config.log_level)
        logger.formatter = Logger::Formatter.new
        @@loggers[name] = logger 
      end
      private
      # Convert symbol log level to Logger log level
      #
      def level(level)
        case level
        when :fatal then Logger::FATAL
        when :error then Logger::ERROR
        when :warn then Logger::WARN
        when :info then Logger::INFO
        when :debug then Logger::DEBUG
        else Logger::ERROR
        end
      end
    end

  end
end
