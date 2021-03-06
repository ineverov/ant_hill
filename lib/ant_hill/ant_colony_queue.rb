module AntHill
  class AntColonyQueue
    
    attr_reader :colonies
    def initialize(config = Configuration.config)
      @config = config
      @colonies = SynchronizedObject.new([], [ :<< , :each, :delete, :inject, :tap ])
    end

    # Create colony
    # +params+:: params for colony
    def add_colony(colony)
      @colonies << colony
    end
    
    def create_colony(params={}, loaded_hash=nil)
      type = params['type'] || loaded_hash && loaded_hash['type']
      colony_class = @config.ant_colony_class(type)
      if colony_class
        colony = colony_class.new(params)
        colony.from_hash(loaded_hash) if loaded_hash
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

    def promote_all_with(params)
      move_all_with(params, :up)
    end

    def demote_all_with(params)
      move_all_with(params, :down)
    end

    def move_all_with(params, direction = :up)
      to_move = @colonies.select{|c| c.is_it_me?(params)} || []
      to_move.each do |colony|
        move_colony(colony, direction)
      end
    end
    private :move_all_with

    def move_colony(colony, direction = :up)
      index = @colonies.index(colony)
      new_index = direction == :up ? index-1 : index+1
      if new_index >= 0 && @colonies[new_index]
        @colonies.tap do |colonies|
          prev = colonies[new_index]
          colonies[index]=colonies[new_index]
          colonies[new_index]=colony
        end
      end
    end
    private :move_colony

    def size
      @colonies.inject(0){|s,c| s+=c.not_processed_size; s}
    end

    def to_hash
      {}.tap{|codder|
        codder['colonies'] = @colonies.collect{|c| c.to_hash}
      }
    end

    def from_hash(codder)
      codder['colonies'].each do |colony_hash|
        add_colony(create_colony({},colony_hash))
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
