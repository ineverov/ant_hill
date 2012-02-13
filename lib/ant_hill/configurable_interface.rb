module AntHill
  class ConfigurableInterface 
    @@classes ||={}
    @@instances ||= {}
    class << self
      def inherited(klass)
        @@classes[config_key] ||=[] 
        @@classes[config_key] << klass
      end

      def get_instance(type, config = Configuration.config)
        type_configuration = config && config['types'] && config['types'][type]
        raise NoSuchGroupDefinedError unless type_configuration
        klass_name = type_configuration && type_configuration[config_key]
        klass = @@classes[config_key].find{|klass| klass.to_s == klass_name}
        raise NoSuchClassDefinedError unless klass
        klass.new
      end

      def config_key
        @config_key
      end

      def instance(type)
        @@instances[config_key] ||= {}
        @@instances[config_key][type] ||= get_instance(type)
      end
    end
    class NoSuchClassDefinedError < Exception; end
    class NoSuchGroupDefinedError < Exception; end
  end
end
