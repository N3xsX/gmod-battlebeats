util.AddNetworkString("BTB_SV_Receive_Sound")
util.AddNetworkString("BTB_Send_Sound")

net.Receive("BTB_SV_Receive_Sound", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    local recipient = net.ReadPlayer()
    local sound = net.ReadString()
    if not sound or sound == "" then return end
    net.Start("BTB_Send_Sound")
    net.WriteString(sound)
    if IsValid(recipient) then
        net.Send(recipient)
    else
        net.Broadcast()
    end
end)
