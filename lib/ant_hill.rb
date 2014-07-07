require 'yaml'
require 'logger'
require 'fileutils'
require 'drb'

# Require file from ant_hill directory
def require_ant_hill(file)
  require "ant_hill/#{file}"
end
private :require_ant_hill

# Main module
module AntHill
end

# Instance of job
require_ant_hill 'ant'
# Configuration
require_ant_hill 'configuration'
# Node
require_ant_hill 'creep'
# Main object 
require_ant_hill 'queen'
# Set of jobs with same logic
require_ant_hill 'ant_colony'
# "Colony" specific logic for setting up and running job
require_ant_hill 'creep_modifier'
# Base connection class
require_ant_hill 'connection_pool'
# SSH connection
require_ant_hill 'connections/ssh_connection'
# Gem version
require_ant_hill 'version'
# logger
require_ant_hill 'log'

