module AntHill
  class Log
    class << self
      @@loggers = {}
      def logger_for(name, config = Configuration.config)
        return @@loggers[name] if @@loggers[name]
        verbose = config.log_level
        path = config.log_dir
        FileUtils.mkdir_p path unless File.exists?(path)
        @@logger[name] = Logger.new(path+"/#{name}.log")
      end
    end

  end
end
