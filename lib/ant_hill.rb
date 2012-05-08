require 'yaml'
require 'logger'
require 'fileutils'
require 'ruby-debug'

def require_ant_hill(file)
  require "ant_hill/#{file}"
end

require_ant_hill 'ant'
#require_ant_hill 'configurable_interface'
require_ant_hill 'configuration'
require_ant_hill 'creep'
require_ant_hill 'queen'
require_ant_hill 'ant_colony'
#require_ant_hill 'ant_finder'
#require_ant_hill 'ant_runner'
#require_ant_hill 'matcher'
require_ant_hill 'creep_modifier'
require_ant_hill 'connection_pool'
require_ant_hill 'connections/ssh_connection'
require_ant_hill 'version'
require_ant_hill 'log'


module AntHill
  # Your code goes here...
end
