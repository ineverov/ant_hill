module AntHill
  class SynchronizedObject < BasicObject
    attr_reader :obj
    def initialize(obj, methods = [])
      @obj = obj
      @methods = methods
      @mutex = ::Mutex.new
    end

    def encode_with(codder)
      codder['obj']=@obj
      codder['methods']=@methods
    end

    def init_with(codder)
      @obj = codder['obj']
      @methods = codder['methods']
      @mutex = Mutex.new
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
