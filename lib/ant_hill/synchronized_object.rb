module AntHill
  class SynchronizedObject < BasicObject
    def initialize(obj, methods = [])
      @obj = obj
      @methods = methods
      @mutex = ::Mutex.new
      nil
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
