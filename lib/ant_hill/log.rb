module AntHill
  class Log
    class << self
      @@loggers = {}
      def logger_for(name, config = Configuration.config)
        return @@loggers[name] if @@loggers[name]
        verbose = config.log_level
        path = config.log_dir
        FileUtils.mkdir_p path unless File.exists?(path)
        logger = Logger.new(path+"/#{name}.log")
        logger.level = level(config.log_level)
        @@loggers[name] = logger 
      end
      private
      def level(level)
        case level
        when :fatal : Logger::FATAL
        when :error : Logger::ERROR
        when :warn : Logger::WARN
        when :info : Logger::INFO
        when :debug : Logger::DEBUG
        else Logger::ERROR
        end
      end
    end

  end
end
