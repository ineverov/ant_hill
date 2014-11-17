module AntHill
  class SynchronizedObject < BasicObject
    attr_reader :obj
    def initialize(obj, methods = [])
      @obj = obj
      @methods = methods
      @mutex = ::Mutex.new
    end

    def method_missing(method, *args, &block)
      if @methods.include? method
        @mutex.synchronize do
          @obj.send(method, *args, &block)
        end
      else
        @obj.send(method, *args, &block)
      end
    end
  end
end
