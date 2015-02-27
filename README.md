For now take a look at the sonos.rb file.

Change the name of the SPEAKER and LIFX_TAG variables to match the speaker and bulb names you want to control.

SUNRISE_SEQUENCE describes the sequence of lighting events in an array of [hue, saturation, value, duration (seconds)].

The light will start to fade on the sum of durations before your sonos alarm goes off (in the case of the default SUNRISE_SEQUENCE, that's 600+600+600+600+0 seconds, or 40 minutes).

Known Bugs
==========

The code doesn't correctly parse out the Day parameters to the alarm, so it will pretty much just look at the time of the next alarm and make the lights come on even if the alarm wasn't due to sound on that day.
