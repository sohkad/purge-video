if SERVER then
  AddCSLuaFile("autorun/sh_gphone.lua")
  AddCSLuaFile("autorun/client/cl_gphone.lua")
end

GPhone = GPhone or {}
GPhone.Version = "0.1.0"

GPhone.Nets = {
  SendText = "gphone_send_text",
  SendPhoto = "gphone_send_photo",
  Incoming = "gphone_incoming",
  CallRequest = "gphone_call_request",
  CallResponse = "gphone_call_response",
  CallState = "gphone_call_state"
}
