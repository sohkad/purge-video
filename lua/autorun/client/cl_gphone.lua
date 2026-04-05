include("autorun/sh_gphone.lua")

local phoneFrame
local phoneHtml

local function safeJSString(str)
  return string.JavascriptSafe(str or "")
end

local function pushEvent(eventName, payload)
  if not IsValid(phoneHtml) then return end
  local json = util.TableToJSON(payload or {}, false)
  phoneHtml:QueueJavascript(string.format("window.gphoneReceive('%s', %s);", safeJSString(eventName), json or "{}"))
end

local function openPhone()
  if IsValid(phoneFrame) then
    phoneFrame:SetVisible(true)
    phoneFrame:MakePopup()
    return
  end

  phoneFrame = vgui.Create("DFrame")
  phoneFrame:SetSize(430, 860)
  phoneFrame:Center()
  phoneFrame:SetTitle("GPhone")
  phoneFrame:MakePopup()

  phoneHtml = vgui.Create("DHTML", phoneFrame)
  phoneHtml:Dock(FILL)
  phoneHtml:OpenURL("asset://garrysmod/html/gphone/index.html")

  phoneHtml:AddFunction("gmod", "sendAction", function(raw)
    local data = util.JSONToTable(raw or "") or {}
    local action = data.action
    local to = tostring(data.to or "")

    if action == "send_text" then
      local text = tostring(data.text or "")
      net.Start(GPhone.Nets.SendText)
        net.WriteString(to)
        net.WriteString(text)
      net.SendToServer()
    elseif action == "send_photo" then
      local quality = math.Clamp(tonumber(data.quality or 35) or 35, 15, 80)
      local jpg = render.Capture({
        format = "jpeg",
        x = 0,
        y = 0,
        w = ScrW(),
        h = ScrH(),
        quality = quality
      })

      if not jpg or #jpg == 0 then
        pushEvent("toast", { message = "Capture photo impossible." })
        return
      end

      if #jpg > 60000 then
        pushEvent("toast", { message = "Photo trop lourde (max 60 KB)." })
        return
      end

      net.Start(GPhone.Nets.SendPhoto)
        net.WriteString(to)
        net.WriteUInt(#jpg, 16)
        net.WriteData(jpg, #jpg)
      net.SendToServer()

      local preview = "data:image/jpeg;base64," .. util.Base64Encode(jpg)
      pushEvent("self_message", {
        from = LocalPlayer():SteamID64(),
        type = "photo",
        text = "",
        photo = preview
      })
    elseif action == "call" then
      net.Start(GPhone.Nets.CallRequest)
        net.WriteString(to)
      net.SendToServer()
    elseif action == "call_response" then
      local resp = tostring(data.response or "decline")
      net.Start(GPhone.Nets.CallResponse)
        net.WriteString(resp)
        net.WriteString(to)
      net.SendToServer()
    end
  end)
end

concommand.Add("gphone_open", openPhone)

hook.Add("OnPlayerChat", "gphone_chat_hint", function(ply, txt)
  if ply ~= LocalPlayer() then return end
  if string.lower(txt or "") == "!phone" then
    openPhone()
    return true
  end
end)

net.Receive(GPhone.Nets.Incoming, function()
  local msgType = net.ReadString()
  local fromId = net.ReadString()
  local text = net.ReadString()
  local photoLen = net.ReadUInt(16)

  local photoData
  if photoLen > 0 then
    photoData = net.ReadData(photoLen)
  end

  local payload = {
    from = fromId,
    type = msgType,
    text = text
  }

  if photoData then
    payload.photo = "data:image/jpeg;base64," .. util.Base64Encode(photoData)
  end

  pushEvent("incoming_message", payload)

  if not IsValid(phoneFrame) or not phoneFrame:IsVisible() then
    chat.AddText(Color(0, 170, 255), "[GPhone] ", color_white, "Nouveau message de " .. fromId)
    surface.PlaySound("buttons/button14.wav")
  end
end)

net.Receive(GPhone.Nets.CallState, function()
  local state = net.ReadString()
  local peerId = net.ReadString()

  pushEvent("call_state", { state = state, peer = peerId })

  if state == "incoming" then
    surface.PlaySound("ambient/alarms/klaxon1.wav")
  elseif state == "connected" then
    chat.AddText(Color(0, 170, 255), "[GPhone] ", color_white, "Appel connecté avec " .. peerId)
  elseif state == "ended" or state == "declined" or state == "no_answer" then
    chat.AddText(Color(0, 170, 255), "[GPhone] ", color_white, "Appel terminé (" .. state .. ")")
  end
end)
