p 'starting..'

pid = Process.fork

if pid.nil? then
  # In child
  exec "elasticsearch -d"
else
  # In parent
  Process.detach(pid)
end

p 'ending..'
