--[[------------------------------------------------------

  editor.Zone
  -----------

  Enables zone editing. This is the main document view: it
  holds editor state information (such as
  current selection, etc).

--]]------------------------------------------------------
local lib    = {type='editor.Zone'}
lib.__index  = lib
editor.Zone  = lib
local private= {}

--=============================================== PUBLIC
setmetatable(lib, {
  -- new method
 __call = function(lib, process_watch, name)
   return lib.new(process_watch, name)
 end
})

function lib.new(process_watch, name)
  local self = {
    name                    = name,
    selected_node_views     = {},
    -- files edited in external editor
    -- OBSOLETE since WebDAV: remove
    observed_files          = {},
    file_observer           = mimas.FileObserver(),
    -- Manage found processes
    found_processes         = {},
    -- Found views
    views                   = {},
    -- Callbacks to trigger when a given process comes online
    on_process_connected    = {},
    -- Callbacks to trigger when a given process goes offline
    on_process_disconnected = {},
  }
  setmetatable(self, lib)

  private.setupLibrary(self)

  private.setupView(self)

  private.setupProcessWatch(self, process_watch or lk.ProcessWatch())

  function self.file_observer.pathChanged(obs, path)
    self:pathChanged(path)
  end
  return self
end

function lib:selectNodeView(node_view, add_to_selection)
  if not add_to_selection then
    for _, view in pairs(self.selected_node_views) do
      view.selected = false
      if not view:deleted() then
        view:update()
      end
    end
    self.selected_node_views = {}
  end
  if node_view then
    self.selected_node_views[node_view] = node_view
    node_view.selected = true
    node_view:update()
  end
end

function lib:deselectNodeView(node_view)
  self.selected_node_views[node_view] = nil
end

function lib:toggleView(process)
  if not process.view then
    process.view = editor.ProcessView(process)
    self.view:addProcessView(process.view)
  else
    process:deleteView()
  end
end

function lib:log(msg_or_url, typ, msg)
  local lv = self.view.log_view
  if not lv then
    return
  end
  if type(msg_or_url) == 'string' then
    if not msg then
      msg = typ
      typ = 'info'
    end
    lv:addMessage(msg_or_url, typ, msg)
  else
    lv:addMessage(msg_or_url.url, msg_or_url.typ, msg_or_url.msg)
  end
end

local basew_path = '/Volumes/Lubyk'
                  --(Lubyk.editor or {}).work_path or
                  --string.format('%s/tmp_lubyk/editor/tmp', os.getenv('HOME'))


function lib:workPath()
  if not self.work_path then
    if lk.exist(basew_path) then
      -- OK, reuse
      self.work_path = basew_path
    else
      self.work_path = basew_path
      lk.makePath(self.work_path)
    end
  end
  return self.work_path
end

local editor_cmd = editor.Settings.editor_cmd
local editor_open_at = editor.Settings.editor_open_at

function lib:editFile(filepath, line)
  -- TODO: properly escape 'url' so that any path works.
  local cmd
  if editor_open_at and line then
    if string.match(editor_open_at, '%%i.*%%s') then
      cmd = string.format(editor_open_at, line, filepath)
    else
      cmd = string.format(editor_open_at, filepath, line)
    end
  elseif editor_cmd and string.match(editor_cmd, '%%s') then
    cmd = string.format(editor_cmd, filepath)
  elseif editor_cmd then
    cmd = string.format("%s '%s'", editor_cmd, filepath)
  else
    cmd = string.format('open "%s"', filepath)
  end
  io.popen(cmd)
end

function lib:editNode(url, line)
  local filepath = self:workPath() .. url .. '.lua'
  self:editFile(filepath, line)
end

function lib:pathChanged(path)
  local node = self.observed_files[path]
  if node then
    node:fileChanged(path)
  end
end

--- User clicked on a link: select it.
function lib:selectLinkView(link_view)
  local old_selection = self.selected_link_view
  -- select link
  self.selected_link_view = link_view
  if old_selection then
    old_selection:update()
  end

  if link_view then
    link_view:update()
  end
end

-- Find a process or the prototypes library view from global position gx, gy.
function lib:processViewAtGlobal(gx, gy)
  local view = self.view and self.view.library_view
  if view and not view.hidden then
    local vx, vy = view:globalPosition()
    if gx > vx and gx < vx + view.w and
      gy > vy and gy < vy + view.h then
      return view
    end
  end

  for _, process in pairs(self.found_processes) do
    local view = process.view
    if view then
      local vx, vy = view:globalPosition()
      if gx > vx and gx < vx + view.w and
         gy > vy and gy < vy + view.h then
        return view
      end
    end
  end
  return nil
end

local function distanceToNode(gx, gy, view)
  local vx, vy = view:globalPosition()
  vx = gx - vx - view.w/2
  vy = gy - vy - view.h/2
  return math.sqrt(vx*vx + vy*vy)
end

-- Find the closest node
function lib:closestNodeAtGlobal(gx, gy)
  local best_node, best_dist
  for _, process in pairs(self.found_processes) do
    if process.type == 'editor.Process' then
      for _, node in pairs(process.nodes) do
        local view = node.view
        if view then
          local dist = distanceToNode(gx, gy, view)
          if (not best_node or dist < best_dist) then
            best_dist = dist
            best_node = node
          end
        end
      end
    end
  end
  return best_node, best_dist
end

--- Find the closest slotView in all processes from the global
-- x and global y coordinates.
-- @return closest slot and distance to center of slot.
function lib:closestSlotView(gx, gy, for_type, skip_node)
  local best_slot, best_dist
  for _, process in pairs(self.found_processes) do
    local view = process.view
    if view then
      local slot, dist = view:closestSlotView(gx, gy, for_type, skip_node)
      if slot and (not best_slot or dist < best_dist) then
        best_dist = dist
        best_slot = slot
      end
    end
  end
  return best_slot, best_dist
end

--=============================================== editor.Process delegate

-- Find (declare) a process.
function lib:findProcess(name, ip, host)
  local process = self.found_processes[name]
  if not process then
    -- create
    if name == '' then
      -- found morph server
      process = editor.Morph(self)
      self.morph = process
    else
      -- process
      process = editor.Process(name, self)
      process.host = host
    end

    process.ip = ip or '-'
    self.found_processes[name] = process
    self.machine_list:addProcess(ip, process)
    self.view:update()
  end

  return process
end

--=============================================== lk.ProcessWatch delegate
function lib:processConnected(remote_process)
  local name = remote_process.name
  local stem_name = string.match(name, '^@(.+)$')
  local process

  if stem_name then
    -- machine (stem cell)
    local machine = self.machine_list:getMachine(stem_name, remote_process.ip)
    process = editor.StemCell {
      name = stem_name,
      host = stem_name,
    }
    self.found_processes[name] = process
    machine:setName(stem_name)
  else
    process = self:findProcess(name, remote_process.ip)
  end

  process:connect(remote_process, self)
  process.ip = remote_process.ip
  -- ip, process
  self.machine_list:addProcess(remote_process.ip, process)

  -- Trigger connection callbacks
  local list = self.on_process_connected
  for i=#list,1,-1 do
    local clbk = list[i]
    if clbk.name == name then
      clbk.clbk()
      table.remove(list, i)
    end
  end
end

function lib:onProcessConnected(name, clbk)
  table.insert(self.on_process_connected, {name = name, clbk = clbk})
end

function lib:onProcessDisconnected(name, clbk)
  table.insert(self.on_process_disconnected, {name = name, clbk = clbk})
end

function lib:processDisconnected(remote_process)
  local name = remote_process.name
  local clear_process = true
  local process = self.found_processes[name]
  if process then
    process:disconnect()
  end

  --- Handle special cases
  if name == '' then
    -- Morph server going offline
    self.found_processes[name] = nil
    self.morph = nil
    -- Remove all pending process tabs
    for name, process in pairs(self.found_processes) do
      process.known_to_morph = false
      if not process.online then
        self:processDisconnected {name = process.name, ip = process.machine.name}
      end
    end
  elseif string.match(name, '^@(.+)$') then
    -- machine (stem cell)
  else
    -- process
    if process then
      --- Update views
      process:deleteView()
      -- this could run anywhere but it has to run after the process is removed
      -- from process_list
      for _, p in pairs(self.found_processes) do
        -- transform outgoing links to the dying process to pending links.
        if p.disconnectProcess then
          p:disconnectProcess(process)
        end
      end
      clear_process = not process.known_to_morph
    end
  end
  if clear_process then
    self.found_processes[name] = nil
    if self.machine_list then
      self.machine_list:removeProcess(process)
    end
  end

  -- Trigger disconnection callbacks
  local list = self.on_process_disconnected
  for i=#list,1,-1 do
    local clbk = list[i]
    if clbk.name == name then
      clbk.clbk()
      table.remove(list, i)
    end
  end
  -- Is this needed ?
  self.view:update()
end

function lib:startStemCell()
  lk.spawn([[
  require 'lubyk'
  stem = lk.StemCell()
  run()
  ]])
end

--=============================================== PRIVATE
function private.setupLibrary(self)
  -- Prototypes library
  self.library = editor.Library {
    table_name = 'prototype',
  }
  -- Update library
  self.library:sync()
  -- Controls library
  self.ctrl_library = editor.Library {
    table_name  = 'control',
    ignore_code = true,
  }
  -- Update library
  self.ctrl_library:sync()
end

function private.setupProcessWatch(self, process_watch)
  -- Start listening for processes and zones on the network
  self.process_watch = process_watch:addDelegate(self)
end

function private.setupView(self)
  local view = editor.ZoneView(self)
  self.view = view
  function view:closed()
    -- when window is closed, we remove this zone
    app:removeZone(self.name)
  end
  self.machine_list = view.machine_list
  self.control_tabs = view.control_tabs
  view:show()
end

