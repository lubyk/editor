--[[------------------------------------------------------

  editor.Node
  -----------

  The Node contains all the information to communicate with
  the remote and also contains a NodeView.

--]]------------------------------------------------------

local lib   = {type='editor.Node'}
lib.__index = lib
editor.Node = lib

-- Minimal width of LineEdit to create node
local MINW = 100
local WeakTable = {__mode = 'v'}
local private = {}

setmetatable(lib, {
  --- Create a new editor.Node reflecting the content of a remote
  -- node. If the process view is not shown, do not create views. If
  -- the view exists, this method must be called in the GUI thread.
 __call = function(lib, process, name, def)
  if not name then
    def     = process
    process = def.process
    name    = def.name
  end

  local self = {
    name           = name,
    hue            = 0.2,
    x              = 100,
    y              = 100,
    inlets         = setmetatable({}, WeakTable),
    outlets        = setmetatable({}, WeakTable),
    -- Sorted slots.
    slots = {
      inlets  = {},
      outlets = {},
    },
    process        = process,
    parent         = process,
    zone           = process.zone,
    -- List of connected controls indexed by param name
    controls       = setmetatable({}, WeakTable),
    -- Sub-nodes
    nodes          = {},
    -- Current param values
    params         = {},
  }

  -- List of inlet prototypes (already linked) to use
  -- on inlet creation.
  if process.pending_inlets[name] then
    self.pending_inlets = process.pending_inlets[name]
    process.pending_inlets[name] = nil
  else
    self.pending_inlets = {}
  end
  setmetatable(self, lib)
  self:set(def)
  return self
end})


--- Called when we receive a change notification from the
-- remote. To actually change the remote Node, use "change".
function lib:set(def)
  local view_update = false
  local reset_params = def.code and true
  for k, v in pairs(def) do
    if k == '_' then
      -- setParams
      private.setParams(self, v, reset_params)
    elseif k == 'code' then
      private.setCode(self, v)
    elseif k == 'hue' or
           k == 'inlets' or
           k == 'has_all_slots' or
           k == 'outlets' then
      -- skip
    else
      view_update = true
      self[k] = v
    end
  end

  self:setHue(def.hue or self.hue)

  if def.inlets then
    private.setSlots(self, 'inlets', def.inlets, def.has_all_slots)
  end

  if def.outlets then
    private.setSlots(self, 'outlets', def.outlets, def.has_all_slots)
  end

  if view_update and self.process.view then
    self:updateView()
  end
end

local function dumpSlots(list)
  local res = {}
  for _, slot in ipairs(list) do
    res[slot.name] = slot:dump()
  end
  return res
end

-- Dump current node definition (used when moving a node from one
-- process to another)
function lib:dump()
  local res = {name = self.name, hue = self.hue, code = self.code}
  res.links = dumpSlots(self.slots.outlets)
  res._ = self.params

  return res
end

function lib:updateView()
  if not self.view then
    self.view = editor.NodeView(self, self.process.view)
  end

  if self.ghost then
    if not self.dragging then
      -- value updated, remove ghost
      self.ghost:delete()
      self.ghost = nil
    else
      self.ghost:updateView()
    end
  end

  -- update needed views
  self.view:updateView()
end

local BG_VALUE           = app.theme.style == 'light' and 0.9 or 0.2
local BG_CVALUE          = app.theme.style == 'light' and 0.6 or 0.8
local SELECTED_BG_VALUE  = app.theme.style == 'light' and 0.7 or 0.6
-- Used by NodeView
lib.SELECTED_BG_VALUE = SELECTED_BG_VALUE

function lib:setHue(hue)
  self.hue      = hue
  self.color    = mimas.Color(self.hue, 0.3, BG_CVALUE) --, 0.8)
  self.bg_color = mimas.Color(self.hue, 0.2, BG_VALUE)
end

function lib:disconnectProcess(process)
  -- We don't need to do this (it's buggy and creates double Link objects).
  -- for _, outlet in ipairs(self.slots.outlets) do
  --   outlet:disconnectProcess(process)
  -- end
end

function lib:error(...)
  print(string.format(...))
--  table.insert(self.errors, string.format(...))
end

--- Try to update the remote end with new data.
function lib:change(definition)
  self.process:change {
    nodes = {
      [self.name] = definition
    }
  }
end

-- edit code in external editor
function lib:edit()
  self.zone:editNode(self:url())
end

function lib:deleteView()
  if self.ghost then
    self.ghost:delete()
    self.ghost = nil
  end

  if self.view then
    self.view:delete()
    self.view  = nil
  end

  for _, list in pairs(self.slots) do
    for _, slot in ipairs(list) do
      slot:deleteViews()
    end
  end
end

function lib:url()
  return self.parent:url() .. '/' .. self.name
end

-- ========== HELPERS

-- Create a ghost node (before it is droped or name is set)
function lib.makeGhost(node_def, zone)
  -- mock a node for NodeView
  local node = {
    name           = node_def.name,
    x              = 0,
    y              = 0,
    slots = {
      inlets  = {},
      outlets = {},
    },
    zone       = zone,
  }
  editor.Node.setHue(node, node_def.hue or 0.2)
  local ghost = editor.NodeView(node, zone.view)
  ghost.is_ghost = true
  ghost:updateView()

  -- this function will be called when the ghost is dropped
  -- or when it appears after double-click
  function ghost:openEditor(finish_func)
    -- add a LineEdit on top of self
    local edit = editor.NodeLineEdit(node.name, zone.library)
	zone.view:addWidget(edit)
    self.edit = edit
    edit:selectAll()
    zone.view:addWidget(edit)
    edit:resize(math.max(self.w, MINW), self.h)
    edit:globalMove(self:globalPosition())
    edit:show()
    edit:setFocus()
    function edit.editingFinished(edit, text)
      if not text or text == '' then
        -- abort
        finish_func(true)
        return
      end
      local name, proto = string.match(text, '^(.*)= *(.*)$')
      if name then
        self.name  = name
        local code = self.zone.library:code(proto)
        if code then
          self.code = code
        else
          -- error
          self.code  = string.format('-- Could not find code for "%s"\n\n', proto)
        end
      else
        self.name = text
      end
      -- call cleanup
      edit:autoFinished()
      -- avoid double call ?
      edit.editingFinished = nil
      finish_func()
    end
  end
  return ghost
end

function lib:delete()
  self:deleteView()
  -- Disconnect controls.
  for k, list in pairs(self.controls) do
    for _, conn in ipairs(list) do
      conn.node = nil
      conn.node_conn_list = nil
      conn.ctrl:change {
        connect = {
          [conn.name] = false,
        }
      }
    end
  end
end

-- Process came online.
function lib:connect()
  self.online = true
  for k, list in pairs(self.controls) do
    for _, conn in ipairs(list) do
      conn:setEnabled(true)
    end
  end
end

-- Process going offline.
function lib:disconnect()
  self.online = false
  for k, list in pairs(self.controls) do
    for _, conn in ipairs(list) do
      conn:setEnabled(false)
    end
  end
end

function lib:connectConnector(conn)
  local param_name = conn.param_name
  local list = self.controls[param_name]
  if not list then
    list = {}
    self.controls[param_name] = list
  end
  table.insert(list, conn)
  -- Avoid list GC before last connection.
  conn.node_conn_list = list
  local param = self.params[param_name]
  if param then
    conn.changed(param.value)
  end
end

-- This is called by connector.
function lib:disconnectConnector(conn)
  local list = self.controls[conn.param_name]
  if list then
    for i, c in ipairs(list) do
      if c == conn then
        table.remove(list, i)
        break
      end
    end
    if #list == 0 then
      self.controls[conn.param_name] = nil
    end
  end
  conn.node_conn_list = nil
  conn.node = nil
end

-- Return a TableView with the fields to edit all of this
-- node's parameters.
function lib:editView()
  -- This gives us the parameter definition.
  local params = self.params
  -- This is from the comments.
  local doc    = self:getDoc()

  local list = {}
  local para
  if doc.params.p then
    for _, def in ipairs(doc.params.p) do
      local key = def.tparam
      -- Sorted params list
      -- TODO: Optimize by storing a cached value built in "getDoc".
      info = (def[1] or {}).text
      local param = params[key]
      table.insert(list, {
        name  = key,
        write = param.default ~= nil,
        value = param.value,
        min   = param.min,
        max   = param.max,
        unit  = param.unit,
        info  = info,
      })
    end
  else
    for key, param in pairs(self.params) do
      lk.insertSorted(list, {
        name  = key,
        write = param.default ~= nil,
        value = param.value,
        min   = param.min,
        max   = param.max,
        unit  = param.unit,
      }, 'name')
    end
  end
  table.insert(list, {name = 'node', value = '', title = true})
  table.insert(list, {name = 'name', value = self.name})
  table.insert(list, {name = 'hue',  write = true, value = self.hue})

  return list
end

-- Return a SimpleDialog view with the fields to edit all of this
-- node's parameters.
--
-- TODO: not used
function lib:editDialog()
  local params = { 
    'vbox', box = true,
  }
  -- TODO use doc order...
  local list = {}
  for key, val in pairs(self.params) do
    -- Sorted params list
    lk.insertSorted(list, {name = key, value = val}, 'name')
  end

  for _, def in ipairs(list) do
    print(def.name)
    table.insert(params, def.name)
    table.insert(params, {'input', def.name, def.value})
  end

  local dlg = mimas.SimpleDialog {
    flag = mimas.WidgetFlag,
    '<h3>'..self.name..'</h3>',
    { 
      'vbox', box = true,
      'name',
      {'input', 'name', self.name},
      'hue',
      {'input', 'hue', self.hue},
    },
    params,
    {
      'hbox', {},
      {'btn', 'cancel'},
      {'btn', 'OK', default=true},
    },
  }
  return dlg
end

--=============================================== PRIVATE

-- We received new parameter values from remote, update the controls.
function private:setParams(def, reset_params)
  if reset_params then private.resetParams(self, def) end

  local params = self.params
  for k, v in pairs(def) do
    local list = self.controls[k]
    if type(v) == 'table' then
      -- Parameter definition change.
      params[k] = v
      if list then
        for _, conn in ipairs(list) do
          -- TODO: update min/max/unit/info settings.
          -- conn.changed(v)
        end
      end
    else
      -- Value change

      -- This is needed first connect operations.
      params[k].value = v

      if list then
        for _, conn in ipairs(list) do
          conn.changed(v)
        end
      end
    end
  end

  if self.reload_edit_view then
    -- Update control view
    self.reload_edit_view()
  end
end

function private:resetParams(def)
  self.params = {}

  for k, list in pairs(self.controls) do
    if def[k] == nil then
      -- disconnect
      for _, conn in ipairs(list) do
        conn.node = nil
        conn.node_conn_list = nil
        conn.ctrl:change {
          connect = {
            [conn.name] = false,
          }
        }
      end
    end
  end
end


function private:setSlots(key, list, has_all_slots)
  local slots = self.slots[key]
  -- Unique key to mark updated slot.
  local mark          = {}
  local slot_by_name  = self[key]
  -- Garbage collection protection during slot parsing.
  local gc = slots
  if has_all_slots then
    -- clear
    slots = {}
    self.slots[key] = slots
  end

  for _, def in ipairs(list) do
    local name = def.name
    local slot = slot_by_name[name]
    if slot then
      slot:set(def)
      if has_all_slots then
        -- Add slot back.
        table.insert(slots, slot)
      end
    else
      -- Add a new inlet/outlet.
      if key == 'inlets' then
        slot = editor.Inlet(self, name, def)
      else
        slot = editor.Outlet(self, name, def)
      end
      table.insert(slots, slot)
      slot_by_name[name] = slot
    end
    if has_all_slots then
      slot.mark = mark
    end
  end

  if has_all_slots then
    for name, slot in pairs(slot_by_name) do
      if slot.mark ~= mark then
        slot_by_name[name] = nil
        if slot.view then
          slot.view:hide()
        end
      end
    end
  end
end

function private:setCode(code)
  if self.code ~= code then
    self.code = code
    self.doc  = nil
    local lv = self.zone.view.log_view
    if lv and lv.selected and lv.selected.url == self:url() and lv.locked then
      lv:unlock()
    end

    for k, list in pairs(self.controls) do
      for _, conn in ipairs(list) do
        conn:updateToolTip()
      end
    end
  end
end

function lib:getDoc()
  if not self.doc then
    -- We could store only needed content (but it might be nice to also
    -- document inlets/outlets ?)
    self.doc = lk.Doc(nil, {name = self.name, code = self.code})
  end
  return self.doc
end
