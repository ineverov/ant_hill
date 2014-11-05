module AntHill
  class AntColonyQueue
    
    attr_readed :colony_queue
    def initialize
      @colonies = SynchronizedObject.new([], [ :<< , :each, :delete ])
    end

    # Create colony
    # +params+:: params for colony
    # +loaded_params+:: loaded params for respawning queen
    def add_colony(colony)
      @colonies << colony
    end
    
    # Find ant for creep
    # +creep+:: creep to find ant
    def find_ant(creep)
      winner = nil
      @colonies.each do |colony|
        winner = max_priority_ant(colony,creep)
        break if winner 
      end
      winner
    end

    # Return ant with max priority for creep
    # +creep+:: creep object
    def max_priority_ant(colony,creep)
      max_ant = nil
      max_priority =-Float::INFINITY
      colony.ants.select{|a| !a.marked? }.each do |a|
        next if a.prior < max_priority
        if (prior=a.priority_cache(creep)) > max_priority
          max_priority = prior
          max_ant = a
        end
      end
      max_ant.mark if max_ant
      max_ant
    rescue NoFreeConnectionError => e
      logger.error "Couldn't find any free connection for creep #{creep}. #{e}: #{e.backtrace.join("\n")}"
      creep.disable!
      nil
    end
    private :max_priority_ant

    # Reset priority for specified creep for all ants
    def reset_priority_for_creep(creep)
      @colonies.each do |colony|
        colony.ants.each{|a| a.delete_cache_for_creep(creep)}
      end
    end
    
    # Kill colonies matching params
    # +params+:: hash of params
    def delete_colony(colony)
      @colonies.delete(colony)
    end
  end
end
