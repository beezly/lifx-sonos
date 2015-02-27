require 'rubygems'
require 'logger'
require 'paint'
require 'lifx'

BULB = "Master Bedroom"
BULB_WAIT = 5

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

client = LIFX::Client.lan
client.discover
sleep BULB_WAIT

logger.info "Turning off bulbs with tag #{BULB}"
client.lights.with_tag(BULB).set_power :off
logger.debug "Flushing"
client.flush
