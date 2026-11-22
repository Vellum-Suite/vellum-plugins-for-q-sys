local plugin = "plugins\\Sennheiser\\Sennheiser-ew-300-500.qplug"
dofile(plugin)

local property = GetProperties()[1]
assert(property.Name == "Receiver Count" and property.Min == 1 and property.Max == 32)
for _, count in ipairs({ 1, 4, 32 }) do
  local props = { ["Receiver Count"] = { Value = count }, page_index = { Value = 1 } }
  local definitions = GetControls(props)
  local configuration = GetControlLayout(props)
  props.page_index.Value = 2
  local monitoring = GetControlLayout(props)
  assert(#definitions == 1 + count * 27)
  for index = 1, count do
    local prefix = string.format("Receiver %02d ", index)
    assert(configuration[prefix .. "IP Address"] and configuration[prefix .. "Online"])
    assert(monitoring[prefix .. "Online"] and monitoring[prefix .. "RF"] and monitoring[prefix .. "Warnings"])
    assert(monitoring[prefix .. "RF 1 Min"] and monitoring[prefix .. "RF 1 Max"])
    assert(monitoring[prefix .. "RF 2 Min"] and monitoring[prefix .. "RF 2 Max"])
    assert(monitoring[prefix .. "RF 1 Meter"].Style == "Meter")
    assert(monitoring[prefix .. "RF 2 Meter"].Style == "Meter")
    assert(monitoring[prefix .. "Audio Meter"] and monitoring[prefix .. "Battery Meter"])
    if index > 1 and index <= 8 then
      assert(monitoring[prefix .. "Name"].Position[1] > monitoring["Receiver 01 Name"].Position[1])
      assert(monitoring[prefix .. "Name"].Position[2] == monitoring["Receiver 01 Name"].Position[2])
    elseif index == 9 then
      assert(monitoring[prefix .. "Name"].Position[2] > monitoring["Receiver 01 Name"].Position[2])
    end
  end
end

local timers, sockets = {}, {}
local failOpen, enforcePortCollision = false, false
local portOwners = {}
local now = 0
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
      if failOpen then error("port already in use") end
      if enforcePortCollision and portOwners[port] then error("port already in use") end
      self.ip, self.port = ip, port
      if enforcePortCollision then portOwners[port] = self end
    end
    function socket:Close()
      if portOwners[self.port] == self then portOwners[self.port] = nil end
    end
    function socket:Send(address, port, data)
      if self.failSend then error("send failed") end
      table.insert(self.writes, { address = address, port = port, data = data })
    end
    function socket:feed(address, data, port)
      self.EventHandler(self, { Address = address, Port = port or 53212, Data = data })
    end
    table.insert(sockets, socket)
    return socket
  end
}

local function makeControls(count)
  Properties = { ["Receiver Count"] = { Value = count } }
  Controls = {}
  for _, definition in ipairs(GetControls(Properties)) do
    Controls[definition.Name] = { String = "", Boolean = false }
  end
end
local function field(index, name)
  return Controls[string.format("Receiver %02d %s", index, name)]
end
local function address(index, value)
  local control = field(index, "IP Address")
  control.String = value
  control.EventHandler()
end
local function advance(timer, seconds)
  for _ = 1, seconds do
    now = now + 1
    timer.EventHandler()
  end
end

makeControls(2)
dofile(plugin)
local socket, timer = sockets[1], timers[1]
assert(socket.ip == nil and socket.port == 53212 and timer.period == 1)
assert(field(1, "Status").String == "Enter IP address")
address(1, "invalid")
assert(field(1, "Status").String == "Invalid IP address")
assert(#socket.writes == 0)
address(1, " 192.168.10.1 ")
address(2, "192.168.10.2")
assert(#socket.writes == 6)
assert(socket.writes[1].address == "192.168.10.1")
assert(socket.writes[1].data == "Push 30 500 7\r" and socket.writes[1].port == 53212)
assert(socket.writes[2].data == "Name\r" and socket.writes[3].data == "Frequency\r")
assert(field(1, "Status").String == "Waiting for telemetry")

socket:feed("192.168.10.1", "Name Vocal 1\rFrequency 822000 2 10\rPush 30 500 7\r")
assert(field(1, "Name").String == "Vocal 1" and field(1, "Frequency").String == "822.000")
assert(not field(1, "Online").Boolean)
socket:feed("192.168.10.1", "RF1 25 65 1\rRF2 28 78 0\rStates 3 2\rRF 150 1 1\rAF 140 165 13\rBat 70\rMsg Low_RF_Signal Low_Battery\rConfig 234\r")
assert(field(1, "Online").Boolean and field(1, "Status").String == "Online")
assert(field(1, "RF").String == "150" and field(1, "Antenna").String == "1" and field(1, "Pilot").String == "Yes")
assert(field(1, "Audio").String == "140" and field(1, "Audio Peak").String == "165")
assert(field(1, "Mute").String == "RF, RX" and field(1, "Battery").String == "70%")
assert(field(1, "Warnings").String == "Low_RF_Signal Low_Battery")
assert(field(1, "RF 1 Min").String == "25" and field(1, "RF 1 Max").String == "65" and field(1, "RF 1 Active").String == "Yes")
assert(field(1, "RF 2 Min").String == "28" and field(1, "RF 2 Max").String == "78" and field(1, "RF 2 Active").String == "No")
assert(field(1, "RF 1 Meter").Value == 65 and field(1, "RF 1 Meter Valid").Boolean)
assert(field(1, "RF 2 Meter").Value == 78 and field(1, "RF 2 Meter Valid").Boolean)
assert(field(1, "Audio Meter").Value == 100 and field(1, "Audio Meter Valid").Boolean)
assert(field(1, "Battery Meter").Value == 70 and field(1, "Battery Meter Valid").Boolean)
assert(not field(2, "Online").Boolean)
socket:feed("192.168.10.2", "RF 50 2 0;RF1 0 0 0;RF2 95 120 1;AF 37 42 3;Bat ?;Msg OK;Config 1\r")
assert(field(2, "RF").String == "50" and field(2, "Mute").String == "TX")
assert(field(2, "Pilot").String == "No" and field(2, "Battery").String == "?")
assert(field(2, "Warnings").String == "OK")
assert(field(2, "RF 1 Max").String == "0" and field(2, "RF 1 Meter").Value == 0 and field(2, "RF 1 Meter Valid").Boolean)
assert(field(2, "RF 2 Max").String == "120" and field(2, "RF 2 Meter").Value == 100)
assert(not field(2, "Battery Meter Valid").Boolean and field(2, "Battery Meter").Value == 0)
socket:feed("192.168.10.1", "RF1 70 30 1\r")
assert(field(1, "RF 1 Max").String == "65" and Controls["Last Error"].String:match("invalid RF1"))
socket:feed("192.168.10.3", "RF 99 1 1\r")
socket:feed("192.168.10.1", "RF 99 1 1\r", 9999)
assert(field(1, "RF").String == "150")
socket:feed("192.168.10.1", "Bat 55\r")
assert(field(1, "Battery").String == "70%" and Controls["Last Error"].String:match("invalid Bat"))
socket:feed("192.168.10.1", "1010: Invalid parameter [ Name ]\r")
assert(Controls["Last Error"].String:match("1010:"))

advance(timer, 4)
socket:feed("192.168.10.1", "AF 12 20 0\r")
advance(timer, 1)
assert(field(1, "Online").Boolean and field(1, "RF").String == "?")
assert(field(1, "Audio").String == "12" and field(1, "Battery").String == "?")
assert(field(1, "RF 1 Min").String == "?" and field(1, "RF 1 Max").String == "?")
assert(not field(1, "RF 1 Meter Valid").Boolean and field(1, "RF 1 Meter").Value == 0)
assert(field(1, "Audio Meter Valid").Boolean and field(1, "Audio Meter").Value == 12)
assert(not field(2, "Online").Boolean and field(2, "Status").String == "Telemetry timeout")
advance(timer, 4)
assert(not field(1, "Online").Boolean and field(1, "Name").String == "?")
assert(field(1, "Audio").String == "?")
advance(timer, 1)
assert(#socket.writes == 12 and socket.writes[7].data == "Push 30 500 7\r")
socket:feed("192.168.10.1", "RF 15 1 1\r")
assert(field(1, "Online").Boolean)

address(2, "192.168.010.001")
assert(field(1, "Status").String == "Duplicate IP address")
assert(field(2, "Status").String == "Duplicate IP address")
assert(not field(1, "Online").Boolean and field(1, "RF").String == "?")
assert(socket.writes[13].data == "Push 0 0 0\r" and socket.writes[14].data == "Push 0 0 0\r")
address(2, "192.168.10.2")
assert(socket.writes[15].address == "192.168.10.1" and socket.writes[15].data == "Push 30 500 7\r")
assert(socket.writes[18].address == "192.168.10.2")
socket:feed("192.168.10.1", "AF 10 20 0\r")
address(1, "192.168.10.4")
assert(socket.writes[21].address == "192.168.10.1" and socket.writes[21].data == "Push 0 0 0\r")
assert(socket.writes[22].address == "192.168.10.4")
socket:feed("192.168.10.1", "AF 10 20 0\r")
assert(not field(1, "Online").Boolean)
socket.failSend = true
address(1, "192.168.10.5")
assert(Controls["Last Error"].String:match("send failed"))

makeControls(1)
field(1, "IP Address").String = "192.168.1.5"
failOpen = true
dofile(plugin)
assert(field(1, "Status").String == "Socket unavailable")
assert(Controls["Last Error"].String:match("port already in use"))
failOpen = false
advance(timers[2], 10)
assert(sockets[#sockets].port == 53212)
assert(field(1, "Status").String == "Waiting for telemetry")
assert(sockets[#sockets].writes[1].data == "Push 30 500 7\r")
assert(#sockets[#sockets].writes == 3)
socket = sockets[#sockets]
socket:feed("192.168.1.5", "RF 50 1 1\r")
now = now + 6
socket:feed("192.168.1.5", "Name Changed\r")
assert(not field(1, "Online").Boolean and field(1, "RF").String == "?")
assert(field(1, "Name").String == "Changed" and field(1, "Status").String == "Telemetry timeout")
socket:feed("192.168.1.5", "RF 40 2 1\r")
assert(field(1, "Online").Boolean and field(1, "Name").String == "Changed")

local function isolatedInstance(first, second)
  local env = setmetatable({ Controls = false }, { __index = _G })
  assert(loadfile(plugin, "t", env))()
  env.Properties = { ["Receiver Count"] = { Value = 2 } }
  env.Controls = {}
  for _, definition in ipairs(env.GetControls(env.Properties)) do
    env.Controls[definition.Name] = { String = "", Boolean = false }
  end
  env.Controls["Receiver 01 IP Address"].String = first
  env.Controls["Receiver 02 IP Address"].String = second
  assert(loadfile(plugin, "t", env))()
  return env, sockets[#sockets]
end
enforcePortCollision = true
local instance1, socket1 = isolatedInstance("192.168.4.1", "192.168.4.2")
local instance2 = isolatedInstance("192.168.4.3", "192.168.4.4")
assert(socket1.port == 53212)
assert(instance2.Controls["Receiver 01 Status"].String == "Socket unavailable")
assert(instance2.Controls["Last Error"].String:match("53212"))
socket1:feed("192.168.4.2", "RF 20 1 1\r")
assert(instance1.Controls["Receiver 02 RF"].String == "20")
assert(not instance1.Controls["Receiver 01 Online"].Boolean)
socket1:Close()
now = now + 10
instance2.ewMonitorTimer.EventHandler()
local socket2 = sockets[#sockets]
assert(socket2.port == 53212 and instance2.Controls["Receiver 01 Status"].String == "Waiting for telemetry")
socket2:feed("192.168.4.4", "RF 40 2 1\r")
assert(instance2.Controls["Receiver 02 RF"].String == "40")
assert(not instance2.Controls["Receiver 01 Online"].Boolean)
print("Sennheiser receiver layout, UDP protocol, and freshness tests passed.")
