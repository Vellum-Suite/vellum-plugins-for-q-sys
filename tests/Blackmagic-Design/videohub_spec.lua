local plugin = "plugins\\Blackmagic-Design\\Blackmagic-Design-Videohub.qplug"
dofile(plugin)

local expected = {
  ["Videohub Mini 4x2 12G"] = { 4, 2 },
  ["Videohub 10x10 12G"] = { 10, 10 },
  ["Videohub 20x20 12G"] = { 20, 20 },
  ["Smart Videohub 12x12"] = { 12, 12 },
  ["Smart Videohub 16x16"] = { 16, 16 },
  ["Smart Videohub 20x20"] = { 20, 20 },
  ["Smart Videohub CleanSwitch 12x12"] = { 12, 12 }
}

for model, size in pairs(expected) do
  local props = { Model = { Value = model }, page_index = { Value = 2 } }
  local controls, layout = GetControls(props), GetControlLayout(props)
  local crosspoints, controlsByName = 0, {}
  for _, control in ipairs(controls) do
    controlsByName[control.Name] = control
    if control.Name:match("^Crosspoint ") then
      crosspoints = crosspoints + 1
      assert(control.PinStyle == "Both" and control.UserPin)
      assert(layout[control.Name], "missing grid control " .. control.Name)
    end
  end
  assert(crosspoints == size[1] * size[2], model .. " crosspoint count")
  for output = 1, size[2] do
    local labelName = "Output " .. output .. " Label"
    local lockName = "Output " .. output .. " Lock"
    assert(controlsByName[labelName], "missing output label pin " .. labelName)
    assert(controlsByName[lockName], "missing output lock pin " .. lockName)
    if output < 10 then
      assert(not controlsByName[string.format("Output %02d Label", output)])
      assert(not controlsByName[string.format("Output %02d Lock", output)])
    end
    local firstCrosspoint = string.format("Crosspoint %02d 01", output)
    assert(layout[firstCrosspoint].PrettyName == "Output " .. output .. "~Input 01")
  end
end

Properties = { Model = { Value = "Videohub 10x10 12G" } }
local connectionLayout = GetControlLayout({ Model = Properties.Model, page_index = { Value = 1 } })
local gridLayout = GetControlLayout({ Model = Properties.Model, page_index = { Value = 2 } })
assert(connectionLayout["Ready"] and connectionLayout["Ready"].Style == "Led")
assert(not gridLayout["Ready"])
Controls = {}
for _, definition in ipairs(GetControls(Properties)) do
  if definition.Name == "Ready" then
    assert(definition.IndicatorType == "Led" and definition.UserPin and definition.PinStyle == "Output")
  end
  Controls[definition.Name] = { String = "", Boolean = false }
end

local timers = {}
Timer = {
  New = function()
    local timer = { running = false }
    function timer:Start(period) self.running, self.period = true, period end
    function timer:Stop() self.running = false end
    table.insert(timers, timer)
    return timer
  end
}
local sockets = {}
TcpSocket = {
  Events = {
    Connected = "connected", Data = "data", Closed = "closed",
    Error = "error", Timeout = "timeout", Reconnect = "reconnect"
  },
  New = function()
    local sock = { writes = {}, incoming = "" }
    function sock:Connect(address, port) self.address, self.port = address, port end
    function sock:Disconnect() self.disconnected = true end
    function sock:Write(data) table.insert(self.writes, data) end
    function sock:Read(length)
      local result = self.incoming:sub(1, length)
      self.incoming = self.incoming:sub(length + 1)
      self.BufferLength = #self.incoming
      return result
    end
    function sock:feed(data)
      self.incoming = self.incoming .. data
      self.BufferLength = #self.incoming
      self.EventHandler(self, TcpSocket.Events.Data)
    end
    table.insert(sockets, sock)
    return sock
  end
}

dofile(plugin)
assert(Controls["Connection"].String == "Enter IP address")
assert(not Controls["Ready"].Boolean)
Controls["IP Address"].String = "not an address"
Controls["IP Address"].EventHandler()
assert(Controls["Connection"].String == "Invalid IP address")
assert(#sockets == 0)
Controls["IP Address"].String = "192.168.10.5"
Controls["IP Address"].EventHandler()
local sock = sockets[1]
assert(sock.address == "192.168.10.5" and sock.port == 9990)
sock.EventHandler(sock, TcpSocket.Events.Connected)
assert(Controls["Connection"].String == "Synchronizing")
assert(not Controls["Ready"].Boolean)
assert(timers[1].running)
timers[1].EventHandler()
assert(sock.writes[1] == "PING:\n\n")

local device = "VIDEOHUB DEVICE:\r\nDevice present: true\r\nModel name: Test Videohub\r\nVideo inputs: 10\r\nVideo outputs: 10\r\n\r\n"
sock:feed(device:sub(1, 23))
sock:feed(device:sub(24, #device - 1))
assert(Controls["Device Model"].String == "")
sock:feed(device:sub(#device))
assert(Controls["Device Model"].String == "Test Videohub")
local routing = "VIDEO OUTPUT ROUTING:\n"
for output = 0, 9 do routing = routing .. output .. " 0\n" end
sock:feed("INPUT LABELS:\n0 Camera A\n\nOUTPUT LABELS:\n0 Program\n\nVIDEO OUTPUT LOCKS:\n0 U\n1 L\n\n" .. routing .. "\n")
assert(Controls["Connection"].String == "Connected")
assert(Controls["Ready"].Boolean)
assert(Controls["Input 01 Label"].String == "Camera A")
assert(Controls["Output 1 Label"].String == "Program")
assert(Controls["Crosspoint 01 01"].Boolean)
assert(not Controls["Crosspoint 01 02"].Boolean)

local select = Controls["Crosspoint 01 02"]
select.Boolean = true
select.EventHandler()
assert(sock.writes[2] == "VIDEO OUTPUT ROUTING:\n0 1\n\n")
assert(not select.Boolean and Controls["Crosspoint 01 01"].Boolean)
sock:feed("ACK\n\nVIDEO OUTPUT ROUTING:\n0 1\n\n")
assert(select.Boolean and not Controls["Crosspoint 01 01"].Boolean)
sock:feed("VIDEO OUTPUT ROUTING:\n0 2\n\n")
assert(not select.Boolean and Controls["Crosspoint 01 03"].Boolean)
sock:feed("VIDEO OUTPUT ROUTING:\n0 99\n\n")
assert(Controls["Connection"].String == "Synchronizing")
assert(not Controls["Ready"].Boolean)
assert(not Controls["Crosspoint 01 03"].Boolean)
assert(Controls["Last Error"].String:match("out%-of%-range"))
sock:feed("VIDEO OUTPUT ROUTING:\n0 2\n\n")
assert(Controls["Connection"].String == "Connected")
assert(Controls["Ready"].Boolean)

local locked = Controls["Crosspoint 02 02"]
locked.Boolean = true
locked.EventHandler()
assert(#sock.writes == 2 and Controls["Last Error"].String:match("locked"))
sock:feed("NAK\n\n")
assert(Controls["Last Error"].String:match("NAK"))

sock.EventHandler(sock, TcpSocket.Events.Closed, "peer closed")
assert(Controls["Connection"].String == "Disconnected")
assert(not Controls["Ready"].Boolean)
assert(not Controls["Crosspoint 01 03"].Boolean and not timers[1].running)
select.Boolean = true
select.EventHandler()
assert(#sock.writes == 2 and Controls["Last Error"].String:match("not synchronized"))
sock.EventHandler(sock, TcpSocket.Events.Connected)
timers[2].EventHandler()
assert(Controls["Connection"].String == "Synchronization incomplete")
assert(not Controls["Ready"].Boolean)
sock:feed("VIDEOHUB DEVICE:\nDevice present: true\nModel name: Wrong\nVideo inputs: 20\nVideo outputs: 20\n\n" .. routing .. "\n")
assert(Controls["Connection"].String == "Model mismatch")
assert(not Controls["Ready"].Boolean)
assert(not Controls["Crosspoint 01 01"].Boolean)
sock:feed(device .. routing .. "\n")
assert(Controls["Connection"].String == "Connected")
assert(Controls["Ready"].Boolean)
sock:feed("VIDEOHUB DEVICE:\nDevice present: false\n\n")
assert(Controls["Connection"].String == "Device unavailable")
assert(not Controls["Ready"].Boolean)
assert(not Controls["Crosspoint 01 01"].Boolean)

Controls["IP Address"].String = "192.168.10.6"
Controls["IP Address"].EventHandler()
assert(sock.disconnected and sock.ReconnectTimeout == 0)
local replacement = sockets[2]
sock.EventHandler(sock, TcpSocket.Events.Closed, "late event")
assert(Controls["Connection"].String == "Connecting")
assert(replacement.address == "192.168.10.6")

Properties = { Model = { Value = "Videohub Mini 4x2 12G" } }
Controls = {}
for _, definition in ipairs(GetControls(Properties)) do
  Controls[definition.Name] = { String = "", Boolean = false }
end
Controls["IP Address"].String = "192.168.10.7"
dofile(plugin)
local mini = sockets[3]
mini.EventHandler(mini, TcpSocket.Events.Connected)
mini:feed("VIDEOHUB DEVICE:\nDevice present: true\nVideo inputs: 4\nVideo outputs: 2\n\nVIDEO OUTPUT ROUTING:\n0 0\n1 3\n\n")
assert(Controls["Connection"].String == "Connected")
assert(Controls["Crosspoint 02 04"].Boolean)
assert(not Controls["Crosspoint 03 01"])
Controls["Crosspoint 02 03"].Boolean = true
Controls["Crosspoint 02 03"].EventHandler()
assert(mini.writes[1] == "VIDEO OUTPUT ROUTING:\n1 2\n\n")
print("Plugin profile, layout, and protocol tests passed.")
