require 'rubygems'
require 'logger'
require 'color'
require 'paint'
require 'lifx'

BULB = "Master Bedroom"
BULB_SATURATION = 0.4
BULB_BRIGHTNESS = 0.05
INTERVAL = 5
BULB_WAIT = 5
CHANGE_DEGREES = 72

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

random = Random.new

hue = random.rand 360

client = LIFX::Client.lan
client.discover
sleep BULB_WAIT

loop do
  logger.debug "Started processing sequence"
  logger.debug "Discovering LIFX clients"
  begin
    logger.debug "Discovered LIFX clients: #{client.lights}"
    hue = (hue + ( random.rand(CHANGE_DEGREES*2)-CHANGE_DEGREES ) ) % 360 
    logger.debug "Selected a delightful shade at #{hue} degrees" 
    colour = LIFX::Color.hsb hue,BULB_SATURATION, BULB_BRIGHTNESS
    logger.debug "Discovered tags: #{client.tags}"
    colour_html = Color::HSL.new(hue, 50, 50).html
    logger.debug "#{colour_html}"
    text_paint = Paint["#{colour}","#{colour_html}"] 
    logger.info "Transitioning tag: #{BULB} to #{text_paint} over #{INTERVAL}s"
    client.lights.with_tag(BULB).set_power :on
    client.lights.with_tag(BULB).set_color(colour, duration: INTERVAL)
    logger.debug "Flushing"
    client.flush
  rescue Exception => e
    logger.error "Failed with #{e}"
  end
  sleep INTERVAL
end
