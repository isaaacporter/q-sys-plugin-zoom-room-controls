-- Status
-- Have an interior status table to aggregate statuses
internalStatus = {}-- Each entry should be a table with:
-- reason: string
-- state: number
--    0: OK (green)
--    1: Compromised (orange)
--    2: Fault (red)
--    3: Not Present (gray)
--    4: Missing (dark red)
--    -1: Initializing (light blue)
statusUpdater = Timer.New()
statusUpdater.EventHandler = function()
  local status = -1
  local reason = ""
  for k, v in pairs(internalStatus) do
    if v.status > status then
      status = v.status
      reason = v.reason
    elseif v.status == status then
      if reason == "" then
        reason = v.reason
      else
        reason = reason .. ", " .. v.reason
      end
    end
  end
  if status == -1 then status = 5 end -- Remap to QSYS values
  if reason == "" then
    Controls["Status"].Value = status
    Controls["Status"].String = ""
  else
    Controls["Status"].Value = status
    Controls["Status"].String = reason
  end
end
statusUpdater:Start(1)


server = TcpSocketServer.New()

-- table to store connected client sockets
-- this is required so the sockets don't
-- get garbage collected since there aren't
-- any other references to them in the script
sockets = {}

function RemoveSocketFromTable(sock)
  for k,v in pairs(sockets) do
    if v == sock then 
      table.remove(sockets, k) 
      if #sockets == 0 then
        internalStatus["plugin"] = {
          status = 4,
          reason = "No clients connected"
        }
      end
      return
    end
  end
end

function RemoveAllSocketFromTable()
  for k,v in pairs(sockets) do
    v:Disconnect()
    table.remove(sockets, k) 
  end
  internalStatus["plugin"] = {
    status = 4,
    reason = "No clients connected"
  }
end

function ParseResponse(dataToParse)
  dataToParse = dataToParse:gsub("[\n\r]", "")
  print("TCP Data Received:"..dataToParse..":")
  for idx = 1, Properties["Command Count"].Value do
    if dataToParse == Controls["command."..idx..".string"].String then
      Controls["command."..idx..".trigger"]:Trigger()
    end
  end
end
 
function SocketHandler(sock, event) -- the arguments for this EventHandler are documented in the EventHandler definition of TcpSocket Properties
  print( "TCP Socket Event:"..event..":")
  if event == TcpSocket.Events.Data then
    ParseResponse(sock:Read(sock.BufferLength))
  elseif event == TcpSocket.Events.Closed or
         event == TcpSocket.Events.Error or
         event == TcpSocket.Events.Timeout then
    -- remove reference of socket from table so
    -- it's available for garbage collection
    RemoveSocketFromTable(sock)
  end
end
 
server.EventHandler = function(SocketInstance) -- the properties of this socket instance are those of the TcpSocket library
  internalStatus["plugin"] = {
    status = 0,
    reason = "Connected"
  }
  print( "Got connect", SocketInstance )
  table.insert(sockets, SocketInstance)
  SocketInstance.EventHandler = SocketHandler
end

function StartServerListening()
  server:Close()
  RemoveAllSocketFromTable()
  server:Listen(Controls["Port"].Value) -- This listen port is opened on all network interfaces
end

Controls["Port"].EventHandler = function()
  StartServerListening()
end

StartServerListening()