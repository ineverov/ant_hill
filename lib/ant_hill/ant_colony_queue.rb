module AntHill
  class AntColonyQueue
    
    attr_reader :colonies
    def initialize(config = Configuration.config)
      @config = config
      @colonies = SynchronizedObject.new([], [ :<< , :each, :delete, :inject ])
    end

    # Create colony
    # +params+:: params for colony
    def add_colony(colony)
      @colonies << colony
    end
    
    def create_colony(params={})
      type = params['type']
      colony_class = @config.ant_colony_class(type)
      if colony_class
        colony = colony_class.new(params)
      else
        colony.logger.error "Couldn't process request #{params} because of previous errors"
      end
      colony
    end

    # Find ant for creep
    # +creep+:: creep to find ant
    def find_ant(creep)
      winner = nil
      @colonies.each do |colony|
        winner = colony.max_priority_ant(colony,creep)
        break if winner 
      end
      winner
    end

    def size
      @colonies.inject(0){|s,c| s+=c.not_processed_size; s}
    end

    def encode_with(codder)
      codder['colonies'] = @colonies
    end

    def init_with(codder)
      @colonies = codder['colonies']
      @config = Configuration.config
    end

    def to_hash
      {}.tap{|codder|
        codder['colonies'] = @colonies.collect{|c| c.to_hash}
      }
    end

    def from_hash(codder)
      codder['colonies'].each do |colony_hash|
        add_colony(AntColony.new.tap{|c| c.from_hash(colony_hash)})
      end
    end

    # Reset priority for specified creep for all ants
    def reset_priority_for_creep(creep)
      @colonies.each do |colony|
        colony.reset_priority_for_creep(creep)
      end
    end
    
    # Kill colonies matching params
    # +params+:: hash of params
    def delete_colony(colony)
      @colonies.delete(colony)
    end
  end
end
