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
  node_tab.title = mimas.Label('')
  node_tab.lay:addWidget(node_tab.title, 0, mimas.AlignLeft + mimas.AlignTop)
  node_tab.msg = mimas.Label('\n')
  node_tab.msg:setWordWrap(true)
  node_tab.msg:setStyle 'font-size:14px; background:#ddd; border:1px solid #999; padding:10px; vertical-align:top'
  node_tab.msg:setMinimumSize(200, 110)
  node_tab.msg:setAlignment(mimas.AlignTop + mimas.AlignLeft)
  node_tab.lay:addWidget(node_tab.msg, 0) --, mimas.AlignLeft + mimas.AlignTop)
  self:addTab(self.node_tab, ' § ')
  -- This is to place node tab just before the end
  table.insert(self.tab_names, '~~')
end

local makeMsg = editor.Connector.makeMsg

function lib:viewNode(node)
  local process = node.process
  local msg = {}
  local msg, setter, node, param_name = makeMsg(process, node:url())

  local list = node:editView()
  local has_msg = false
  for _, elem in ipairs(list) do
    if elem.info then
      has_msg = true
      break
    end
  end

  local tooltip = self.node_tab.msg
  if not has_msg then
    tooltip:hide()
  else
    tooltip:show()
  end


  local titles = {'Results', 'Advanced', 'More', 'ThisThat'}
  for i, _ in ipairs(list) do
    if i % 6 == 0 then
      table.insert(list, i, {name = titles[i/6], value = '', title = true})
    end
  end

  if self.node_dlg and not self.node_dlg:deleted() then
    self.node_dlg:hide()
  end

  --=============================================== 
  local tv = mimas.TableView()
  self.node_dlg = tv

  tv:setEditTriggers(
    mimas.AnyKeyPressed   +
    mimas.DoubleClicked   +
    mimas.SelectedClicked + 
    0
  )
  tv:setAlternatingRowColors(true)

  if true then
    -- use cells as headers
    --tv:setStretchHorizontal(true)
    --tv:setStretchVertical(false)
    tv:setShowHorizontalHeader(false)
    tv:setShowVerticalHeader(false)
    -- Ignore CSS style
    -- tv:foobar()

    function tv:columnCount() return 2 end
    function tv:rowCount() return #list end
    function tv:data(row, col)
      if col == 1 then
        return list[row].name
      else
        return list[row].value
      end
    end

    function tv:selected(row, col)
      if row then
        tooltip:setText(
          tv:tooltip(row, 1)
        )
      else
        tooltip:setText('')
      end
      return true
    end

    function tv:keyboard(key, on)
      if key == mimas.Key_Return and on then
        -- go to next row
        local row, col = self:currentIndex()
        tv:setCurrentIndex(row + 1, col)
      end
      return true
    end

    function tv:setData(row, col, value)
      if value == '' then return false end
      row = list[row]
      if row then row.value = value end
    end

    local cell_flags = mimas.ItemIsEditable + mimas.ItemIsEnabled + mimas.ItemIsSelectable
    local title_flags = mimas.ItemIsEnabled
    function tv:flags(row, col)
      if col == 1 then
        return 0
      else
        return list[row].title and title_flags or cell_flags
      end
    end

    function tv:tooltip(row, col)
      return '<b>'..list[row].name..'</b><br/>' ..(list[row].info or '')
    end

    function tv:header(section, orientation)
      if orientation == mimas.Vertical then
        return list[section].name
      end
    end

    function tv:background(row, col)
      if list[row].title then
        return mimas.Color(0, 0, 0.2)
      elseif col == 1 then
        -- header
        return mimas.Color(0, 0, 0.8)
      end
    end

    function tv:foreground(row, col)
      if list[row].title then
        return mimas.Color(0, 0, 1)
      end
    end

    function tv:sizeHintForColumn(col)
      -- Why isn't this called for column 2 ?
      return col == 1 and 240 or 20
    end
    
    tv:resizeColumnsToContents()
  else
    -- use headers
    tv:setStretchHorizontal(true)
    tv:setStretchVertical(false)
    tv:setShowHorizontalHeader(true)
    tv:setShowVerticalHeader(true)
    -- Ignore CSS style
    -- tv:foobar()

    function tv:columnCount() return 1 end
    function tv:rowCount() return #list end
    function tv:data(row, col)
      return list[row].value
    end

    function tv:selected(row, col)
      if row then
        tooltip:setText(
          tv:tooltip(row, 1)
        )
      else
        tooltip:setText('')
      end
      return true
    end

    function tv:keyboard(key, on)
      if key == mimas.Key_Return and on then
        -- go to next row
        local row, col = self:currentIndex()
        tv:setCurrentIndex(row + 1, col)
      end
      return true
    end

    function tv:setData(row, col, value)
      if value == '' then return false end
      row = list[row]
      if row then row.value = value end
    end

    local cell_flags = mimas.ItemIsEditable + mimas.ItemIsEnabled + mimas.ItemIsSelectable
    local title_flags = mimas.ItemIsEnabled
    function tv:flags(row, col)
      return list[row].title and title_flags or cell_flags
    end

    function tv:tooltip(row, col)
      return '<b>'..list[row].name..'</b>: ' ..list[row].info
    end

    function tv:header(section, orientation)
      if orientation == mimas.Vertical then
        return list[section].name
      end
    end

    function tv:background(row, col)
      if list[row].title then
        return mimas.Color(0, 0, 0.2)
      elseif not col then
        -- header
        return mimas.Color(0, 0, 0.8)
      end
    end

    function tv:foreground(row, col)
      if list[row].title then
        return mimas.Color(0.6, 0.9, 0.5)
      end
    end

    -- function tv:sizeHintForColumn(col)
    --   -- Why isn't this called for column 2 ?
    --   print(col, 'sizeHintForColumn')
    --   return col == 1 and 240 or 20
    -- end
    
    -- tv:resizeColumnsToContents()
  end
  --=============================================== 

  self.node_tab.title:setText('<h2>'..node.name..'</h2>')

  self.node_tab.lay:addWidget(tv, 2) --, 0, mimas.AlignTop + mimas.AlignLeft)

  -- function dlg.btn(dlg, btn_name)
  --   if btn_name == 'OK' then
  --     -- send param updates
  --     for k, v in pairs(dlg.form) do
  --       if k == 'name' or k == 'hue' then
  --         if k == 'name' then
  --           -- FIXME
  --         else
  --           -- node change
  --           msg.nodes[node.name][k] = v
  --         end
  --       else
  --         -- param change
  --         setter[k] = tonumber(v)
  --       end
  --     end
  --     print(yaml.dump(msg))
  --     process.push:send(UPDATE_URL, msg)
  --   else
  --     -- remove or reset dlg
  --   end
  --   self.node_dlg = nil
  --   dlg:hide()
  -- end
end

function lib:removePlusView()
  self.add_tab:hide()
  self.add_tab:__gc()
  self.add_tab = nil
end
