--[[------------------------------------------------------

  editor.ControlTabs
  ------------------

  Displays all the views in a tabbed interface.

--]]------------------------------------------------------
local lib = lk.SubClass(mimas.TabWidget)
editor.ControlTabs = lib

local private = {}
local UPDATE_URL = lubyk.update_url

-- constants
function lib:init(zone_view)
  self.zone_view = zone_view
  self.zone = zone_view.zone
  self.tab_names = {}
end

function lib:addView(name, def)
  local view_name = string.match(name, '^%d+_(.+)$') or name
  local view = editor.ControlView(name, def, self.zone)
  -- insert sorted
  local done 
  for i, tab_name in ipairs(self.tab_names) do
    if name < tab_name then
      table.insert(self.tab_names, i, name)
      self:insertTab(i, view, view_name)
      done = true
      break
    end
  end

  if not done then
    table.insert(self.tab_names, name)
    self:addTab(view, view_name)
  end

  self:selectTab(1)
  return view
end

function lib:resized(w, h)
  self.width  = w
  self.height = h
end

function lib:hide()
  self.super:hide()
  if self.zone.machine_list then
    self.zone.machine_list:controlViewChanged(false)
  end
end

function lib:show()
  self.super:show()
  if self.zone.machine_list then
    self.zone.machine_list:controlViewChanged(true)
  end
end

function lib:addPlusView()
  local zone = self.zone
  local add = mimas.Widget()
  self.add_tab = add
  add.lay = mimas.VBoxLayout(add)
  add.dlg = mimas.SimpleDialog {
    flag = mimas.WidgetFlag,
    'Create a new view',
    {'vbox', box=true, style='background: '..app.theme.alt_background,
      'view name',
      {'input', 'name', 'base'},
    },
    {'hbox',
      {}, -- this adds stretch
      {'btn', 'Cancel'},
      {'btn', 'OK', default=true},
    },
  }
  add.lay:addWidget(add.dlg, 0, mimas.AlignCenter)
  function add.dlg:btn(btn_name)
    if btn_name == 'OK' then
      -- create view
      local morph = zone.morph
      if morph then
        morph:change {
          _views = {
            [self.form.name] = {},
          },
        }
      end
    else
      -- do nothing
    end
  end
  self:addTab(self.add_tab, '+')
  -- This is to place add_tab at the end
  table.insert(self.tab_names, '~~~')
end

function lib:addNodeView()
  local zone = self.zone
  local node_tab = mimas.Widget()
  self.node_tab = node_tab
  node_tab.lay = mimas.VBoxLayout(node_tab)
  self:addTab(self.node_tab, ' § ')
  -- This is to place node tab just before the end
  table.insert(self.tab_names, '~~')
end

local makeMsg = editor.Connector.makeMsg

function lib:viewNode(node)
  local process = node.process
  local msg = {}
  local msg, setter, node, param_name = makeMsg(process, node:url())

  local dlg = node:editView()
  if self.node_dlg and not self.node_dlg:deleted() then
    self.node_dlg:hide()
  end
  self.node_dlg = dlg

  self.node_tab.lay:addWidget(dlg, 0, mimas.AlignTop + mimas.AlignLeft)
  function dlg.btn(dlg, btn_name)
    if btn_name == 'OK' then
      -- send param updates
      for k, v in pairs(dlg.form) do
        if k == 'name' or k == 'hue' then
          if k == 'name' then
            -- FIXME
          else
            -- node change
            msg.nodes[node.name][k] = v
          end
        else
          -- param change
          setter[k] = tonumber(v)
        end
      end
      print(yaml.dump(msg))
      process.push:send(UPDATE_URL, msg)
    else
      -- remove or reset dlg
    end
    self.node_dlg = nil
    dlg:hide()
  end
end

function lib:removePlusView()
  self.add_tab:hide()
  self.add_tab:__gc()
  self.add_tab = nil
end
