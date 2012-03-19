require 'ant_hill'

task :add_colony do
  AntHill::Queen.create_colony ARGV[1..-1]
end

task :monitor do
  while true
    sleep 2
    print "\e[2J\e[f"
    puts "Ants left: #{AntHill::Queen.drb_queen.size}"
    AntHill::Queen.creeps.each{|creep|
      puts creep.to_s
    }
  end
end

task :execute_each do
  threads = []
  AntHill::Queen.creeps.each{|creep|
    threads << Thread.new do
       creep.exec!(ENV['command'])
    end
  }
  threads.each{ |t| t.join}
end

