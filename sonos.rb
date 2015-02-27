require 'rubygems'
require 'logger'
require 'sonos'
require 'lifx'
require 'matrix'


SPEAKER = "Master Bedroom"
LIFX_TAG = "Master Bedroom Pendant"
LIFX_RETRIES = 3
SUNRISE_SEQUENCE = [[200,1,0.0001,0],[200,1,0.1,600],[240,0.3,0.15,600],[50,0.5,1,600],[55,0.6,1,600]]
SONOS_OFFSET = 2
POLL_INTERVAL = 120

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

def alarm_light tag, start_time, duration, sequence, logger, client
  logger.debug "Thread started for tag: #{tag}, start_time #{start_time} for #{duration}s"
  now = Time.now
  sequence_duration = sequence.map {|x| x[3]}.inject{|sum,x| sum + x }
  logger.debug "Total sequence duration is #{sequence_duration}s"
  logger.debug "Discovered LIFX clients: #{client.lights}"
  sequence_duration += SONOS_OFFSET
  
  time_til_alarm = start_time-now
  
  delay = (time_til_alarm < sequence_duration ) ? 0 : (start_time-now)-sequence_duration
  
  logger.info "Waiting for #{delay}s"
  sleep delay
  
  # We wait here until we're ready to wake up
  
  sequence.each do |seq| 
    logger.debug "Started processing sequence"
    logger.debug "Discovering LIFX clients"
    begin
      logger.debug "Discovered LIFX clients: #{client.lights}"
      h,s,b,d = seq
      colour = LIFX::Color.hsb h,s,b
      logger.debug "Discovered tags: #{client.tags}"
      logger.info "Transitioning tag: #{tag} to #{colour} over #{d}s"
      client.lights.with_label(tag).set_power :on
      client.lights.with_label(tag).set_color(colour, duration: d)
      logger.debug "Flushing"
      client.flush
    rescue Exception => e
      logger.error "Failed with #{e}"
    end
    sleep d if d > 0
  end
  
  # Wait and turn off after our duration
  
  logger.info "Waiting for #{duration}s"
  sleep duration
  
  # And turn off again
  logger.debug "Discovering LIFX clients"
  client.lights.with_label(tag).set_power :off
  logger.debug "Thread completed for tag: #{tag}, start_time #{start_time} for #{duration}s"
end

alarm_threads = []
client = LIFX::Client.lan
client.discover

loop do
  
  begin
    logger.debug "Polling SONOS"
    system = Sonos::System.new
    speaker = system.speakers.find { |v| v.name==SPEAKER }

    enabled_alarms = speaker.list_alarms.find_all { |k,v| v[:Enabled]=='1' }
  rescue 
    logger.warn "Could not talk to SONOS. Retrying..."
    retry
  end
  
  alarms_defined = enabled_alarms.map do |alarm_id, alarm_data|
    start_time_hms = alarm_data[:StartLocalTime].split(':')
    now = Time.now
    start_time = Time.local(
      now.year, 
      now.month, 
      now.day, 
      start_time_hms[0],
      start_time_hms[1],
      start_time_hms[2])

    if start_time < now
      start_time+=(60*60*24)
    end
    
    duration_hms = alarm_data[:Duration].split(':')
    duration=(duration_hms[0].to_i*60*60)+
             (duration_hms[1].to_i*60)+
             (duration_hms[2].to_i)

    { start_time: start_time, duration: duration }
  end

  logger.debug "Alarm Threads: #{alarm_threads}"
  alarm_thread_map = alarm_threads.map { |t| {start_time: t[:start_time], duration: t[:duration]}}
  
  alarms_not_needed = alarm_thread_map.reject do |alarm|
    alarms_defined.include?({start_time: alarm[:start_time], duration: alarm[:duration]})
  end
  
  alarms_needed = alarms_defined.reject do |alarm|
    alarm_thread_map.include?({start_time: alarm[:start_time], duration: alarm[:duration]})
  end
  
  if alarms_needed.length > 0 or alarms_not_needed.length > 0 
    logger.info "Alarm changes: #{alarms_needed.length} added, #{alarms_not_needed.length} removed"
  end
  
  alarms_not_needed.map do |alarm|
    thread = alarm_threads.find { |t| t[:start_time] == alarm[:start_time] and t[:duration] == alarm[:duration]}
    
    # Only kill the thread if its start_time is in the future, otherwise just remove it from the thread list
    
    if thread[:start_time] > Time.now
      logger.info "Destroying thread for Alarm: #{thread[:start_time]}, duration: #{thread[:duration]}s, thread: #{thread[:thread]}"
      Thread.kill thread[:thread]
    end
    alarm_threads.reject! {|x| x == thread }
  end

  alarms_needed.map do |alarm|
    logger.info "Creating thread for Alarm: #{alarm[:start_time]}, duration: #{alarm[:duration]}s"
    alarm_threads << { start_time: alarm[:start_time], duration: alarm[:duration], thread: Thread.new { alarm_light(LIFX_TAG, alarm[:start_time], alarm[:duration],SUNRISE_SEQUENCE,logger,client) }}
  end
  
  sleep POLL_INTERVAL
end
