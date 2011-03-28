--[[------------------------------------------------------

  editor.Process
  --------------

  The editor.Process manages the connection with the
  remote Process and holds information on the state of the
  remote. This is like lk.Client but with a single
  subscription.

--]]------------------------------------------------------

local lib      = {type='editor.Process'}
lib.__index    = lib
editor.Process = lib

setmetatable(lib, {
  -- new method
 __call = function(table, remote_service)
  local instance = {
    name          = remote_service.name,
    push          = remote_service.push,
    nodes         = {},
    pending_nodes = {},
  }

  if remote_service.info.hue then
    instance.hue = remote_service.info.hue
  else
    instance.hue = 0.5
  end
  -- the little view on the side
  instance.tab = editor.ProcessTab(instance)

  --======================================= SUB client
  instance.sub = zmq.SimpleSub(function(...)
    -- we receive notifications
    -- ...
  end)
  instance.sub:connect(remote_service.sub_url)

  setmetatable(instance, lib)
  return instance
end})

--- Nodes in patch changed, store change and update view if needed.
-- To remove a node, set it's value to false.
local function update_nodes(self, nodes_def)
  local nodes = self.nodes
  for node_name, node_def in pairs(nodes_def) do
    local node = nodes[node_name]
    if node then
      if node_def then
        -- update existing node
        node:update(node_def)
      else
        -- remove node
        node:remove()
        nodes[node_name] = nil
      end
    elseif node_def then
      -- create new node
      node = editor.Node(node_def, self)
      nodes[node_name] = node
    end
  end
end

local function do_update(self, definition)
  if definition.name then
    self.name = definition.name
    if self.view then
      self.view:setName(self.name)
    end
  end

  local nodes = definition.nodes
  if nodes then
    update_nodes(self, nodes)
  end
end

-- If self.view is nil, only update the data without
-- creating/changing views.
function lib:update(definition)
  if self.view then
    app:post(function()
      do_update(self, definition)
    end)
  else
    do_update(self, definition)
  end
end

function lib:send(...)
  self.push:send(...)
end

-- find a node in the current process (same as lk.Patch.get).
lib.get = lk.Patch.get

-- Create a pending inlet (same as lk.Patch.inlet_pending).

-- Create a pending inlet.
function lib:inlet_pending(inlet_url)
  local parts = lk.split(inlet_url, '/')
  local node_name, inlet_name
  if #parts == 3 and parts[2] == 'in' then
    node_name, inlet_name = parts[1], parts[3]
  else
    -- FIXME: store absolute path for 'in_url' in process pending list
    -- and resolve this list on node creation
    return nil, string.format("Invalid link url '%s' (target not found and cannot create temporary).", in_url)
  end

  local node = self.nodes[node_name]
  local inlet = nil
  if node then
    -- inlet not created yet
    inlet = editor.Inlet(inlet_name)
    node.inlets_pending[node_name] = inlet
  else
    -- node not created yet
    local pending_node = self.pending_nodes[node_name]
    if not pending_node then
      pending_node = {}
      self.pending_nodes[node_name] = pending_node
    end
    inlet = pending_node[inlet_name]
    if not inlet then
      inlet = editor.Inlet(inlet_name)
      pending_node[inlet_name] = inlet
    end
  end
  return inlet
end
