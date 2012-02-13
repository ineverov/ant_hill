module AntHill
  class Matcher < ConfigurableInterface
    @config_key = 'matcher_class'
  end

  class DefaultMatcher < Matcher
    def match(param, value1, value2)
      value1 == value2
    end
  end
end
