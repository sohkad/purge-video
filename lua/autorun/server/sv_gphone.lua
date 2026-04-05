AddCSLuaFile("autorun/sh_gphone.lua")
AddCSLuaFile("autorun/client/cl_gphone.lua")

include("autorun/sh_gphone.lua")

for _, netName in pairs(GPhone.Nets) do
  util.AddNetworkString(netName)
end

local function findTargetBySteamID64(id)
  for _, ply in ipairs(player.GetAll()) do
    if ply:SteamID64() == id then
      return ply
    end
  end
end

local rateLimiter = {}
local function checkRate(ply, key, delay)
  rateLimiter[ply] = rateLimiter[ply] or {}
  local now = CurTime()
  local nextAllowed = rateLimiter[ply][key] or 0
  if now < nextAllowed then return false end
  rateLimiter[ply][key] = now + delay
  return true
end

hook.Add("PlayerDisconnected", "gphone_cleanup_rate", function(ply)
  rateLimiter[ply] = nil
end)

local calls = {}
local function setCallState(a, b, state)
  if not (IsValid(a) and IsValid(b)) then return end

  net.Start(GPhone.Nets.CallState)
    net.WriteString(state)
    net.WriteString(b:SteamID64())
  net.Send(a)

  net.Start(GPhone.Nets.CallState)
    net.WriteString(state)
    net.WriteString(a:SteamID64())
  net.Send(b)
end

net.Receive(GPhone.Nets.SendText, function(_, sender)
  if not checkRate(sender, "text", 0.3) then return end

  local toId = net.ReadString()
  local message = string.Trim(net.ReadString() or "")

  if #message == 0 or #message > 400 then return end

  local target = findTargetBySteamID64(toId)
  if not IsValid(target) then return end

  net.Start(GPhone.Nets.Incoming)
    net.WriteString("text")
    net.WriteString(sender:SteamID64())
    net.WriteString(message)
    net.WriteUInt(0, 16)
  net.Send(target)
end)

net.Receive(GPhone.Nets.SendPhoto, function(_, sender)
  if not checkRate(sender, "photo", 1.5) then return end

  local toId = net.ReadString()
  local photoLen = net.ReadUInt(16)
  if photoLen == 0 or photoLen > 60000 then return end

  local bytes = net.ReadData(photoLen)
  local target = findTargetBySteamID64(toId)
  if not IsValid(target) then return end

  net.Start(GPhone.Nets.Incoming)
    net.WriteString("photo")
    net.WriteString(sender:SteamID64())
    net.WriteString("")
    net.WriteUInt(photoLen, 16)
    net.WriteData(bytes, photoLen)
  net.Send(target)
end)

net.Receive(GPhone.Nets.CallRequest, function(_, sender)
  if not checkRate(sender, "call", 1.0) then return end

  local toId = net.ReadString()
  local target = findTargetBySteamID64(toId)
  if not IsValid(target) or target == sender then return end

  if calls[sender] or calls[target] then
    net.Start(GPhone.Nets.CallState)
      net.WriteString("busy")
      net.WriteString(target:SteamID64())
    net.Send(sender)
    return
  end

  calls[sender] = { peer = target, state = "ringing" }
  calls[target] = { peer = sender, state = "ringing" }

  net.Start(GPhone.Nets.CallState)
    net.WriteString("outgoing")
    net.WriteString(target:SteamID64())
  net.Send(sender)

  net.Start(GPhone.Nets.CallState)
    net.WriteString("incoming")
    net.WriteString(sender:SteamID64())
  net.Send(target)

  timer.Create("gphone_call_timeout_" .. sender:SteamID64(), 30, 1, function()
    if not (IsValid(sender) and IsValid(target)) then return end
    if not calls[sender] or calls[sender].state ~= "ringing" then return end

    setCallState(sender, target, "no_answer")
    calls[sender] = nil
    calls[target] = nil
  end)
end)

net.Receive(GPhone.Nets.CallResponse, function(_, sender)
  local action = net.ReadString() -- accept|decline|hangup
  local peerId = net.ReadString()

  local peer = findTargetBySteamID64(peerId)
  if not IsValid(peer) then return end

  local call = calls[sender]
  if not call or call.peer ~= peer then return end

  if action == "accept" then
    calls[sender].state = "connected"
    calls[peer].state = "connected"
    setCallState(sender, peer, "connected")
  elseif action == "decline" then
    setCallState(sender, peer, "declined")
    calls[sender] = nil
    calls[peer] = nil
  elseif action == "hangup" then
    setCallState(sender, peer, "ended")
    calls[sender] = nil
    calls[peer] = nil
  end
end)

hook.Add("PlayerDisconnected", "gphone_cleanup_call", function(ply)
  local call = calls[ply]
  if not call then return end
  local peer = call.peer

  calls[ply] = nil
  if IsValid(peer) then
    calls[peer] = nil
    net.Start(GPhone.Nets.CallState)
      net.WriteString("ended")
      net.WriteString(ply:SteamID64())
    net.Send(peer)
  end
end)
