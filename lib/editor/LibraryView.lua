--[[------------------------------------------------------

  editor.LibraryView
  ------------------

  Displays the LibraryView.

--]]------------------------------------------------------
local lib = lk.SubClass(mimas.Widget)
editor.LibraryView = lib
lib.type = 'editor.LibraryView'
local private = {}

--=============================================== CONSTANTS
local WIDTH       = 120
local PADDING     = 10
local ROW_HEIGHT  = 10
local BAR_HEIGHT  = 50 -- toolbar at the top
local MIN_HEIGHT  = BAR_HEIGHT + ROW_HEIGHT + 50
local DRAG_POS_X  = 10
local DRAG_POS_Y  = 10
local START_DRAG_DIST = 4

local MousePress,       MouseRelease,       DoubleClick =
      mimas.MousePress, mimas.MouseRelease, mimas.DoubleClick

--=============================================== PUBLIC
function lib:init(library, zone)
  self.library = library
  self.table_name = library.table_name
  self.zone    = zone
  self.vbox    = mimas.VBoxLayout(self)

  --=============================== Search field
  private.setupSearch(self)
  --=============================== List view
  private.setupListView(self)

  --self.vbox:addStretch()

  --=============================== General settings

  self.w = WIDTH
  self.h = MIN_HEIGHT
  self.vbox:setContentsMargins(2,10,2,2)
  self.vbox:setSpacing(2)
  self:setSizePolicy(mimas.Fixed, mimas.Minimum)
  self:setSizeHint(WIDTH, MIN_HEIGHT)
  self:resize(self.w, self.h)
end

function lib:resized(w, h)
  self.w = w
  self.h = h
end

function lib:paint(p, w, h)
  if self == self.zone.process_view_under then
    -- under drag operation
    p:fillRect(0, 0, w, h, mimas.Color(0.5, 0.5, 0.5))
  else
    p:fillRect(0, 0, w, h, mimas.Color(0, 0, 0.18))
  end
end

--=============================================== PRIVATE

function private:clickInList(info, x, y, op, btn, mod)
  if op == MousePress and info then
    if btn == RightButton or mod == mimas.MetaModifier then
      local sx, sy = self:globalPosition()
      -- Select line
      local row_i = self.list_view:indexAt(x, y)
      self.list_view:selectRow(row_i)
      self.list_view:update()
      private.showContextMenu(self, sx + math.max(0, x - 40), sy + y + 40, info)
    else
      -- store position but only start drag when moved START_DRAG_DIST away
      self.click_position = {
        x        = x,
        y        = y,
      }
      self.selected_obj = info
    end
  elseif op == DoubleClick then
    -- noop
  elseif op == MouseRelease then
    if self.dragging then
      --=============================================== DROP OBJECT
      private[self.table_name].drop(self)
    else
      -- select row ?
    end
  end
  -- Pass to normal list selection and click handling
  return true 
end

function private.manhattanDist(a, b)
  return math.abs(b.x - a.x) + math.abs(b.y - a.y)
end

function private:mouseInList(x, y)
  if not self.dragging and self.click_position and private.manhattanDist(self.click_position, {x=x,y=y}) > START_DRAG_DIST then
    -- start drag operation: self becomes ghost
    self.dragging = true
    self.gx, self.gy = self.list_view:globalPosition()
    private[self.table_name].drag(self)
  end

  local ghost = self.ghost
  if ghost then
    ghost.gx = self.gx + x - DRAG_POS_X
    ghost.gy = self.gy + y - DRAG_POS_Y
    ghost:globalMove(ghost.gx, ghost.gy)
    local zone = self.zone
    local old_process_view_under = zone.process_view_under
    zone.process_view_under = zone:processViewAtGlobal(ghost.gx + DRAG_POS_X, ghost.gy + DRAG_POS_Y)
    if zone.process_view_under then
      zone.process_view_under:update()
    end
    if old_process_view_under then
      old_process_view_under:update()
    end
  end
end

function private:updateFilter(filter)
  self.filter = filter
  self.list_view:reset()
end

--=============================================== Search
function private:setupSearch()
  local s = mimas.LineEdit()
  self.search = s
  s:setFocusPolicy(mimas.ClickFocus)
  function s.textEdited(_, text)
    private.updateFilter(self, text)
  end
  self.vbox:addWidget(s)
end


local SELECT_COLOR = mimas.Color(0.1, 1, 0.3)
local MousePress = mimas.MousePress
--=============================================== ListView
function private:setupListView()
  local lv = self
  local library = self.library
  local view = mimas.ListView()
  self.list_view = view
  view.lib_view = self

  self.vbox:addWidget(view)

  function view:rowCount()
    return library:nodeCount(lv.filter)
  end

  function view:data(row_i)
    return library:node(lv.filter, row_i).name
  end

  function view:click(x, y, op, btn, mod)
    local row_i = self:indexAt(x, y)
    local node_def
    if op == MousePress and row_i then
      node_def = library:node(lv.filter, row_i)
      lv.selected_row = row_i
    elseif not lv.dragging then
      lv.selected_row = nil
      self:update()
    end
    return private.clickInList(self.lib_view, node_def, x, y, op, btn, mod)
  end

  view:enablePaintItem(true)
  local align = mimas.AlignLeft + mimas.AlignVCenter
  function view:paintItem(p, x, y, w, h, row)
    if lv.selected_row == row then
      p:fillRect(x, y, w, h, SELECT_COLOR)
    end
    local fullname = library:node(lv.filter, row).name
    local base, name = string.match(fullname, '^(.*%.)(.-)$')
    name = name or fullname
    local tw, th = view.super:textSize(base)
    if base then
      p:setPen(mimas.Pen(1, app.theme._color ))
      p:drawText(x+6, y+2, tw+3, th+2, align, base)
      x = x + 7 + tw
    end

    p:setPen(mimas.Pen(1, app.theme._high_color))
    local tw, th = view.super:textSize(name)
    p:drawText(x+2, y+2, tw+5, th+2, align, name)
  end

  function view:mouse(x, y)
    private.mouseInList(self.lib_view, x, y)
  end
end

--=============================================== Prototype
function lib:dropNode(node)
  local abort = false
  local code, name

  -- add a LineEdit on top of self
  local edit = mimas.LineEdit(node.name)
  self:addWidget(edit)
  edit:selectAll()
  edit:resize(self.w, node.ghost.h)
  local gx, gy = node.ghost:globalPosition()
  gx = self:globalPosition()
  edit:globalMove(gx, gy)
  edit:show()
  edit:setFocus()

  local function finish(name, code)
    if name then
      self.library:addNode(name, code)
      private.updateFilter(self, '')
    end

    -- clear
    self.zone.process_view_under = nil
    self:update()
  end

  function edit.editingFinished(edit, name)
    if not name or name == '' then
      -- abort
      finish()
    else
      if not string.match(name, '%.') then
        name = os.getenv('USER') .. '.' .. name
      end
      if not string.match(name, '^~') then name = '~' .. name end
      finish(name, node.code)
    end
    
    -- avoid double call ?
    edit.editingFinished = nil
    edit:hide()
  end

  function edit:keyboard(key, on)
    if on and key == mimas.Key_Escape then
      self:editingFinished()
      self:hide()
    else
      -- normal ops
      return true
    end
  end

  node.dragging = false
  node:updateView()
end

private.prototype = {}

function private.prototype:drag()
  -- mock a node for NodeView
  self.ghost = editor.Node.makeGhost(self.selected_obj, self.zone)
end

function private.prototype:drop()
  self.ghost:openEditor(function(abort)
    if not abort then
      local node_def = self.selected_obj
      node_def.name = self.ghost.name
      node_def.code = self.ghost.code or node_def.code
      local process_view = self.zone.process_view_under
      if process_view then
        local process = process_view.process
        -- create node
        -- target:change {}
        local vx, vy = process_view:globalPosition()
        local x = self.ghost.gx - vx
        local y = self.ghost.gy - vy
        process:newNode {
          x = self.ghost.gx - vx,
          y = self.ghost.gy - vy,
          code = node_def.code,
          name = node_def.name,
          hue  = process.hue,
        }
        process_view:update()
      end
    end

    -- clear
    self.zone.process_view_under = nil
    self.ghost:delete()
    self.ghost = nil
    self.click_position = nil
    self.dragging = nil
    self.selected_row = nil
  end)
end

--=============================================== Control
private.control = {}
local getControl = editor.Control.getControl

function private.control:drag()
  local obj  = self.selected_obj
  local ctor = getControl(obj.name)
  if ctor then
    self.ghost = ctor()
    self.ghost.is_ghost = true
    -- Add to currently selected view
    print('1', self.zone)
    print('2', self.zone.view)
    print('3', self.zone.view.control_tabs)
    print('4', self.zone.view.control_tabs:currentWidget())
    self.zone.view.control_tabs:currentWidget():addWidget(self.ghost)
    self.ghost:show()
  end
end

function private.control:drop()
  local view  = self.zone.view.control_tabs:currentWidget()
  local typ   = self.selected_obj.name
  local id    = view:nextName(typ) -- nextName ???
  local ghost = self.ghost
  -- On id update callback
  view:onUpdate(id, function()
    ghost:hide()
  end)
  view:change {
    [id] = {
      type = typ,
      x    = self.ghost:x(),
      y    = self.ghost:y(),
      hue  = self.ghost.hue,
    },
  }

  -- clear
  self.click_position = nil
  self.dragging = nil
  self.selected_row = nil
end

function private:showContextMenu(gx, gy, info)
  local menu = mimas.Menu('')
  if self.menu and not menu:deleted() then
    self.menu:hide()
  end
  self.menu = menu

  menu:addAction('Remove', '', function()
    self.library:removeNode(info.name)
    self.list_view:reset()
  end)

  menu:popup(gx, gy)
end

