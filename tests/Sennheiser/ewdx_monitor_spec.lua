local plugin = "plugins\\Sennheiser\\Sennheiser-ew-dx.qplug"
dofile(plugin)

for _, model in ipairs({ "EW-DX EM 2", "EW-DX EM 2 Dante", "EW-DX EM 4 Dante" }) do
  local count = model == "EW-DX EM 4 Dante" and 4 or 2
  local props = { Model = { Value = model }, page_index = { Value = 1 } }
  local definitions = GetControls(props)
  assert(#definitions == 6 + count * 20)
  local config = GetControlLayout(props)
  assert(config["IP Address"] and config["Protocol"] and config["Password"])
  props.page_index.Value = 2
  local monitor = GetControlLayout(props)
  assert(monitor.Online and monitor.Status)
  assert(monitor["Channel " .. count .. " RF Strength"])
  assert(monitor["Channel 1 RF Strength Meter"].Style == "Meter")
  assert(monitor["Channel 1 RF Quality Meter"] and monitor["Channel 1 Audio Level Meter"] and monitor["Channel 1 Battery Meter"])
  assert(monitor["Channel " .. count .. " TX Warnings"])
  assert(monitor["Channel 2 Name"].Position[1] > monitor["Channel 1 Name"].Position[1])
  assert(monitor["Channel 2 Name"].Position[2] == monitor["Channel 1 Name"].Position[2])
  for _, definition in ipairs(definitions) do
    if definition.Name == "Channel 1 RF Strength Meter" then
      assert(definition.Min == -107 and definition.Max == 0 and definition.PinStyle == "Output")
    elseif definition.Name == "Channel 1 Audio Level Meter" then
      assert(definition.Min == -138.5 and definition.Max == 0)
    end
  end
  assert(not monitor["Channel " .. (count + 1) .. " RF Strength"])
end

local null = function() end
local fixtures, encoded = {}, {}
package.preload.rapidjson = function()
  return {
    null = null,
    encode = function(value) table.insert(encoded, value); return "encoded request" end,
    decode = function(value) return fixtures[value] end
  }
end
local now, timers, sockets, requests = 0, {}, {}, {}
local failOpen = false
Timer = {
  Now = function() return now end,
  New = function()
    local timer = {}
    function timer:Start(period) self.period = period end
    table.insert(timers, timer)
    return timer
  end
}
UdpSocket = {
  New = function()
    local socket = { writes = {} }
    function socket:Open(ip, port)
      if failOpen then error("open failed") end
      self.ip, self.port, self.open = ip, port, true
    end
    function socket:Close() self.open = false end
    function socket:Send(ip, port, data)
      table.insert(self.writes, { ip = ip, port = port, data = data })
    end
    function socket:feed(ip, port, value)
      local key = "udp fixture"
      fixtures[key] = value
      self.EventHandler(self, { Address = ip, Port = port, Data = key })
    end
    table.insert(sockets, socket)
    return socket
  end
}
HttpClient = { Download = function(request) table.insert(requests, request) end }

local function newInstance(model, ip, protocol, password)
  Controls = nil
  dofile(plugin)
  Properties = { Model = { Value = model } }
  Controls = {}
  for _, definition in ipairs(GetControls(Properties)) do
    Controls[definition.Name] = { String = "", Boolean = false }
  end
  Controls["IP Address"].String = ip or ""
  Controls["Protocol"].String = protocol or ""
  Controls["Password"].String = password or ""
  dofile(plugin)
  return Controls, timers[#timers]
end
local function tick(timer, seconds)
  now = now + (seconds or 0.25)
  timer.EventHandler()
end
local function edit(controls, name, value)
  controls[name].String = value
  controls[name].EventHandler()
end
local function respond(request, code, value)
  local key = "http fixture"
  fixtures[key] = value
  request.EventHandler(request, code, key, nil, {})
end

local c, timer = newInstance("EW-DX EM 2", "192.168.1.10", "SSCv1")
assert(timer.period == 0.25)
tick(timer)
local socket = sockets[#sockets]
assert(socket.open and socket.port == nil and socket.ip == nil)
assert(socket.writes[1].port == 45 and socket.writes[1].ip == "192.168.1.10")
local poll = encoded[#encoded]
assert(poll.rx1.frequency == null and poll.rx2.mates == null)
assert(poll.m.rx1.rssi == null and poll.m.rx2.af == null)
socket:feed("192.168.1.10", 45, {
  rx1 = { name = "Vocal", frequency = 650025, mute = false, warnings = {}, mates = { "mates/tx2" } },
  m = { rx1 = { rssi = -75.5, rsqi = 0, divi = 1, af = -20 }, rx2 = { rssi = -107 } }
})
assert(c.Online.Boolean and c["Channel 1 Name"].String == "Vocal")
assert(c["Channel 1 Frequency"].String == "650.025" and c["Channel 1 RX Mute"].String == "No")
assert(c["Channel 1 RF Quality"].String == "0" and c["Channel 1 Warnings"].String == "None")
assert(c["Channel 1 Antenna"].String == "A" and c["Channel 1 Audio Level"].String == "-20.0")
assert(c["Channel 1 RF Strength Meter"].Value == -75.5 and c["Channel 1 RF Strength Meter Valid"].Boolean)
assert(c["Channel 1 RF Quality Meter"].Value == 0 and c["Channel 1 RF Quality Meter Valid"].Boolean)
assert(c["Channel 1 Audio Level Meter"].Value == -20 and c["Channel 1 Audio Level Meter Valid"].Boolean)
assert(c["Channel 2 RF Strength Meter"].Value == -107 and c["Channel 2 RF Strength Meter Valid"].Boolean)
tick(timer, 2)
poll = encoded[#encoded]
assert(poll.mates.tx2.battery.gauge == null and poll.mates.tx2.battery.lifetime == null)
assert(poll.mates.tx2.mute == null and poll.mates.tx2.warnings == null)
socket:feed("192.168.1.10", 45, { mates = { tx2 = { battery = { gauge = 0, lifetime = 60 }, mute = false, warnings = { "LowBattery" } } } })
assert(c["Channel 1 Battery"].String == "0" and c["Channel 1 Battery Runtime"].String == "60")
assert(c["Channel 1 Battery Meter"].Value == 0 and c["Channel 1 Battery Meter Valid"].Boolean)
assert(c["Channel 1 TX Mute"].String == "No" and c["Channel 1 TX Warnings"].String == "LowBattery")
socket:feed("192.168.1.10", 45, { mates = { tx2 = { battery = { gauge = 30 } } } })
assert(c["Channel 1 Battery"].String == "30" and c["Channel 1 Battery Runtime"].String == "60")
socket:feed("192.168.1.11", 45, { rx1 = { name = "Wrong" } })
socket:feed("192.168.1.10", 46, { rx1 = { name = "Wrong" } })
assert(c["Channel 1 Name"].String == "Vocal")
socket:feed("192.168.1.10", 45, { osc = { error = { { mates = { tx2 = { battery = { gauge = { 424 } } } } } } } })
assert(c["Channel 1 Battery"].String == "?" and c["Channel 1 Battery Runtime"].String == "60")
assert(not c["Channel 1 Battery Meter Valid"].Boolean and c["Channel 1 Battery Meter"].Value == 0)
socket:feed("192.168.1.10", 45, { osc = { error = { { rx1 = { name = { 404 } } } } } })
assert(c["Last Error"].String:match("404") and c["Last Error"].String:match("/rx1/name"))
assert(c["Channel 1 Name"].String == "?")
tick(timer, 20)
socket:feed("192.168.1.10", 45, { m = { rx1 = { rsqi = 77 } } })
tick(timer, 21)
assert(c.Online.Boolean and c["Channel 1 Frequency"].String == "?")
assert(c["Channel 1 RF Quality"].String == "77")
assert(not c["Channel 1 RF Strength Meter Valid"].Boolean and c["Channel 1 RF Strength Meter"].Value == -107)
assert(c["Channel 1 RF Quality Meter Valid"].Boolean and c["Channel 1 RF Quality Meter"].Value == 77)
tick(timer, 20)
assert(not c.Online.Boolean and c.Status.String == "Telemetry timeout")
assert(c["Channel 1 Name"].String == "?")
edit(c, "IP Address", "192.168.1.20")
assert(not socket.open and c.Status.String == "Waiting for telemetry")
tick(timer)
assert(sockets[#sockets] ~= socket and sockets[#sockets].port == nil)

failOpen = true
local failed, failedTimer = newInstance("EW-DX EM 2", "192.168.1.30", "SSCv1")
tick(failedTimer)
assert(failed.Status.String == "Socket unavailable" and failed["Last Error"].String:match("socket"))
failOpen = false
tick(failedTimer, 10)
assert(failed.Status.String == "Waiting for telemetry" and sockets[#sockets].open)
tick(failedTimer, 40)
assert(failed.Status.String == "Telemetry timeout" and not failed.Online.Boolean)

local v2, v2Timer = newInstance("EW-DX EM 4 Dante", "192.168.2.1", "SSCv2", "secret")
tick(v2Timer)
local request = requests[#requests]
assert(request.Url == "https://192.168.2.1/api/channel/0")
assert(request.User == "api" and request.Password == "secret" and request.Auth == "basic")
assert(request.Timeout == 5)
local requestCount = #requests
tick(v2Timer)
assert(#requests == requestCount)
respond(request, 200, { name = "Main", mute = false, mates = { "TX3" } })
assert(v2.Online.Boolean and v2["Channel 1 RX Mute"].String == "No")
tick(v2Timer); request = requests[#requests]
assert(request.Url:match("/api/channel/0/warnings$"))
respond(request, 200, {})
assert(v2["Channel 1 Warnings"].String == "None")
tick(v2Timer); request = requests[#requests]
assert(request.Url:match("/api/rf/channels/0$"))
respond(request, 200, { frequency = 823200 })
assert(v2["Channel 1 Frequency"].String == "823.200")
for _, sample in ipairs({
  { "signalStrengthIndicator", -80 }, { "signalQualityIndicator", 0 },
  { "diversityIndicator", 2 }, { "level", -30 }
}) do
  tick(v2Timer); request = requests[#requests]
  assert(request.Url:match("/" .. sample[1] .. "$"))
  respond(request, 200, { value = sample[2] })
end
assert(v2["Channel 1 RF Strength"].String == "-80.0" and v2["Channel 1 Antenna"].String == "B")
assert(v2["Channel 1 RF Strength Meter"].Value == -80 and v2["Channel 1 RF Strength Meter Valid"].Boolean)
tick(v2Timer); request = requests[#requests]
assert(request.Url:match("/api/transmitters/2/battery$"))
respond(request, 200, { gauge = 0, lifetime = 25 })
assert(v2["Channel 1 Battery"].String == "0")
tick(v2Timer); request = requests[#requests]
assert(request.Url:match("/api/transmitters/2$"))
respond(request, 200, { mute = false })
assert(v2["Channel 1 TX Mute"].String == "No")
tick(v2Timer); request = requests[#requests]
assert(request.Url:match("/api/transmitters/2/warnings$"))
respond(request, 200, { "LowBattery" })
assert(v2["Channel 1 TX Warnings"].String == "LowBattery")

-- A reconfiguration invalidates an outstanding callback.
tick(v2Timer); request = requests[#requests]
edit(v2, "IP Address", "192.168.2.2")
respond(request, 200, { name = "Stale", mute = true, mates = { "TX2" } })
assert(not v2.Online.Boolean and v2["Channel 2 Name"].String == "?")
tick(v2Timer); request = requests[#requests]
assert(request.Url == "https://192.168.2.2/api/channel/0")
respond(request, 401, {})
assert(not v2.Online.Boolean and v2.Status.String:match("authentication"))
assert(not v2["Channel 1 RF Strength Meter Valid"].Boolean and v2["Channel 1 RF Strength Meter"].Value == -107)
assert(not v2["Last Error"].String:match("secret"))
requestCount = #requests
tick(v2Timer, 4)
assert(#requests == requestCount)
tick(v2Timer, 1)
request = requests[#requests]
respond(request, 403, {})
assert(v2.Status.String:match("forbidden"))
tick(v2Timer, 5); request = requests[#requests]
respond(request, -1, {})
assert(not v2.Online.Boolean and v2.Status.String:match("HTTPS request failed"))

local empty, emptyTimer = newInstance("EW-DX EM 2", "192.168.3.1", "SSCv2", "secret")
tick(emptyTimer); request = requests[#requests]
respond(request, 200, { name = "Mic", mute = true, mates = { "TX1" } })
for _ = 1, 6 do tick(emptyTimer); respond(requests[#requests], 200, {}) end
tick(emptyTimer); request = requests[#requests]
assert(request.Url:match("/api/transmitters/0/battery$"))
respond(request, 422, {})
assert(empty.Online.Boolean and empty["Channel 1 Battery"].String == "?")
tick(emptyTimer); request = requests[#requests]
respond(request, 422, {})
assert(empty["Channel 1 TX Mute"].String == "?")
tick(emptyTimer); request = requests[#requests]
tick(emptyTimer, 7)
assert(empty.Status.String == "HTTPS request timed out")
respond(request, 200, { name = "Late" })
assert(not empty.Online.Boolean and empty["Channel 2 Name"].String == "?")

local four, fourTimer = newInstance("EW-DX EM 4 Dante", "192.168.4.1", "SSCv2", "secret")
for step = 1, 40 do
  tick(fourTimer)
  local current = requests[#requests]
  local url = current.Url
  if url:match("/api/channel/%d$") then
    local index = tonumber(url:match("(%d)$")) + 1
    respond(current, 200, { name = "CH" .. index, mute = false, mates = { "TX" .. index } })
  elseif url:match("/api/rf/channels/") then respond(current, 200, { frequency = 650025 })
  elseif url:match("/battery$") then respond(current, 200, { gauge = 50, lifetime = 60 })
  elseif url:match("/warnings$") then respond(current, 200, {})
  elseif url:match("/api/transmitters/%d$") then respond(current, 200, { mute = false })
  else respond(current, 200, { value = 0 }) end
end
assert(four["Channel 4 Name"].String == "CH4" and four["Channel 4 Battery"].String == "50")
assert(requests[#requests].Url:match("/api/transmitters/3/warnings$"))
print("Sennheiser EW-DX layout, SSCv1 and SSCv2 tests passed.")
