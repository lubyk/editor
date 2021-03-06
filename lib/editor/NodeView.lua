--[[------------------------------------------------------

  editor.NodeView
  ---------------

  The NodeView show a single node with inlets and outlets.

--]]------------------------------------------------------
local lib = lk.SubClass(mimas.Widget)
editor.NodeView = lib
local private = {}

--============================================= PRIVATE
-- constants
local BOX_PADDING = 1
local HPEN_WIDTH  = 1 -- half pen width
local BP = HPEN_WIDTH + BOX_PADDING -- full box padding
local ARC_RADIUS = 0
local TEXT_HPADDING = 8
local TEXT_VPADDING = 4
local PAD  = BP + HPEN_WIDTH -- padding for inner shape (top/left)
local SLOTH        = editor.SlotView.SLOTH
local SLOTW        = editor.SlotView.SLOTW
local SLOT_PADDING = editor.SlotView.SLOT_PADDING
local MINW         = 60
local GHOST_ALPHA  = 0.3
local SELECTED_COLOR_VALUE = editor.Node.SELECTED_BG_VALUE
local START_DRAG_DIST = 4
local DRAG_CORNER = 20

local function updateSlotViews(list)
  for _, slot in ipairs(list) do
    -- create/update views for each slot
    slot:updateView()
  end
end

local function placeSlots(self, slot_list, x, y, max_x)
  for _, slot in ipairs(slot_list) do
    local key
    if self.is_ghost then
      view = slot.ghost
    else
      view = slot.view
    end
    if view then
      if x > max_x then
        view:hide()
      else
        view:show()
      end
      view:move(x, y)
      slot:updateLinkViews()
    end
    x = x + SLOTW + SLOT_PADDING
  end
end

local function placeElements(self)
  private.setMinSize(self)
  -- inlets
  placeSlots(self,
    self.node.slots.inlets,
    -- start x
    PAD + TEXT_HPADDING,
    -- start y
    PAD,
    -- max x
    self.w - SLOTW - PAD
  )

  placeSlots(self,
    self.node.slots.outlets,
    -- start x
    PAD + TEXT_HPADDING,
    -- start y
    self.h - PAD - SLOTH,
    -- max x
    self.w - SLOTW - PAD
  )
end

--============================================= PUBLIC
function lib:init(node, parent_view)
  self.node = node
  self.zone = node.zone
  self:setName(node.name)
  if parent_view then
    -- If we do not cache these, they end up wrong (resized callback?)
    local w, h = self.w, self.h
    parent_view:addWidget(self)
    self:resize(w, h)
    self:show()
  else
    print('Start NodeView without parent')
  end
end

function lib:updateView()
  local node = self.node
  -- We use global position to cope with ghost views
  if not self.is_ghost then
    self:move(node.x, node.y)
  end
  updateSlotViews(node.slots.inlets)
  updateSlotViews(node.slots.outlets)
  placeElements(self)
  -- forces redraw
  self:update()
end

function lib:setName(name)
  self.name  = name
  private.setMinSize(self)
end

function lib:animate(typ, max_wait, timeout_clbk)
  local bsat
  local hue = self.node.hue
  if typ == 'error' then
    hue = 0
    bsat = 1
  elseif typ == 'warn' then
    hue = 0.1
  end
  if self.anim then
    self.anim:kill()
  end
  self.anim = lk.Thread(function()
    local start_time = elapsed()
    local t = 0
    local i = 0
    while t <= max_wait do
      i = i + 1
      sleep(0.5)
      t = elapsed() - start_time
      -- blink 
      local sat = (0.75 + 0.2 * math.cos(t * math.pi / 750)) % 1.0
      self.anim_back = mimas.Color(hue, bsat or sat, sat, 0.5)
      if not self:deleted() then
        self:update()
      end
    end
    if timeout_clbk then
      timeout_clbk()
    end
    self.anim_back = nil
    self.anim = nil
  end)
end

function lib:resized(w, h)
  self.w = w
  self.h = h
  placeElements(self)
end

-- custom paint
function lib:paint(p, w, h)
  local back   = self.anim_back or self.node.bg_color
  local border = self.node.color
  -- label width/height
  local path = mimas.Path()

  -- draw node surface
  if self.is_ghost then
    p:setBrush(back:colorWithAlpha(GHOST_ALPHA))
    p:setPen(HPEN_WIDTH * 2, border:colorWithAlpha(GHOST_ALPHA))
  elseif self.selected then
    p:setBrush(back:colorWithValue(SELECTED_COLOR_VALUE))
    p:setPen(HPEN_WIDTH * 2, border)
  else
    p:setBrush(back)
    p:setPen(HPEN_WIDTH * 2, border)
  end
  p:drawRoundedRect(BP, BP, w - 2 * BP, h - 2 * BP, ARC_RADIUS / 2)

  -- draw label text
  local color = app.theme._high_color
  if self.is_ghost then
    p:setPen(1, color:colorWithAlpha(GHOST_ALPHA))
  else
    p:setPen(1, color)
  end
  p:drawText(PAD+TEXT_HPADDING, PAD+TEXT_VPADDING, w-2*TEXT_HPADDING-2*PAD, h - 2*TEXT_VPADDING - 2*PAD, mimas.AlignLeft + mimas.AlignVCenter, self.name)
end

local MousePress,       MouseRelease,       DoubleClick =
      mimas.MousePress, mimas.MouseRelease, mimas.DoubleClick

local RightButton = mimas.RightButton

local function makeGhost(self)
  local node = self.node
  -- create a ghost
  local ghost = editor.NodeView(node, self.zone.view)
  ghost.is_ghost = true
  node.ghost = ghost
  node.dragging = true
  -- ghost on top
  ghost:raise()
end

function lib:click(x, y, op, btn, mod)
  local node = self.node
  if btn == RightButton or
     mod == mimas.MetaModifier then
    if op == MousePress then
      -- Show contextual menu
      local sx, sy = self:globalPosition()
      private.showContextMenu(self, sx + x, sy + y)
    end
  elseif op == MousePress then
    -- store position but only start drag when moved START_DRAG_DIST away
    self.click_position = {x = x, y = y}
    -- DISABLE RESIZING. BETTER TO HAVE A WIDTH FIXED BY SLOT AND TITLE.
    --if x > self.w - DRAG_CORNER and y > self.h - DRAG_CORNER then
    --  -- resize
    --  self.resizing = true
    --else
      self.resizing = false
    --end
  elseif op == DoubleClick then
    -- open external editor
    node:edit()
    self.zone:selectNodeView(self)
  elseif op == MouseRelease then
    if node.dragging then
      private.endDrag(self)
    else
      self.zone:selectNodeView(self, mod == mimas.ShiftModifier)
      self.zone.control_tabs:viewNode(node)
    end
  end
end

local function manhattanDist(a, b)
  return math.abs(b.x - a.x) + math.abs(b.y - a.y)
end

function lib:mouse(x, y)
  local node = self.node
  if not node.ghost and manhattanDist(self.click_position, {x=x,y=y}) > START_DRAG_DIST then
    -- start drag operation
    makeGhost(self)
  end

  if node.ghost then
    local zone = self.node.process.zone
    local ghost = node.ghost
    local gpx, gpy = self.node.process.view:globalPosition()

    if self.resizing then
      -- resizing
      local w = self.w + x - self.click_position.x
      local h = self.h + y - self.click_position.y
      self.click_position.x = x
      self.click_position.y = y
      self:resize(w, h)
    else
      local gx = gpx + node.x + x - self.click_position.x
      local gy = gpy + node.y + y - self.click_position.y
      ghost:globalMove(gx, gy)

      local old_process_view_under = zone.process_view_under
      local pv = zone:processViewAtGlobal(gx + self.click_position.x, gy + self.click_position.y)

      zone.process_view_under = pv

      if pv then
        if pv == (node.process and node.process.view) then
          pv.highlight = false
        else
          pv.highlight = true
        end
        pv:update()
      end

      if old_process_view_under and old_process_view_under ~= pv then
        old_process_view_under.highlight = false
        old_process_view_under:update()
      end
    end

    ghost:updateView()
  end
end

function lib:delete()
  self:hide()
  if self.edit then
    self.edit:hide()
  end
  if self.selected then
    -- remove ghost from selection my selecting only self
    self.zone:selectNodeView(self)
  end
  self.super:__gc()
end

--=============================================== PRIVATE

function private:showContextMenu(gx, gy)
  if self.is_ghost then
    return false
  end

  local menu = mimas.Menu('')
  if self.menu and not menu:deleted() then
    self.menu:hide()
  end
  self.menu = menu

  menu:addAction('Link', '', function()
    local link_editor = editor.LinkEditor(self.zone)
    self.zone.view.link_editor = link_editor
    link_editor:setNode(self.node)
  end)

  menu:addAction('Remove', '', function()
    self.node:change(false)
  end)

  menu:popup(gx - 5, gy - 5)
end

function private:setMinSize()
  local w, h = self.super:textSize(self.name)
  local slots = self.node.slots
  local count = math.max(#slots.outlets, #slots.inlets)
  local slot_w = PAD + TEXT_HPADDING +
                 count * (SLOTW + SLOT_PADDING)

  self.w = math.max(w + 2 * TEXT_HPADDING + 2*PAD, MINW, slot_w)
  self.h = h + 2 * TEXT_VPADDING + 2*PAD
  self:setSizeHint(self.w, self.h)
  self:setSizePolicy(mimas.Minimum, mimas.Fixed)
  self:resize(self.w, self.h)
  self:update()
end

function private:endDrag()
  local node = self.node
  local zone = self.node.process.zone
  -- drop
  -- detect drop zone
  -- Drop on prototype library ?

  -- Drop on process ?

  -- Drop out of process view = remove ?
  local view = zone.process_view_under
  if view and view.type == 'editor.LibraryView' then
    view:dropNode(node)
    return
  elseif not view then
    node.dragging = false
    node:updateView()
    return
  end

  local process = view.process

  local gx,  gy  = node.ghost:globalPosition()
  local gpx, gpy = process.view:globalPosition()
  local node_x = gx - gpx
  local node_y = gy - gpy

  if node.process ~= process then
    -- Processes to update
    local changed_processes = {}
    local old_process = self.node.process
    -- moving from one process to another
    local def = self.node:dump()
    def.x, def.y = node_x, node_y

    -- Remove from old process
    changed_processes[old_process] = {
      nodes = {
        [self.node.name] = false,
      }
    }
    -- Add in new process
    changed_processes[process] = {
      nodes = {
        [self.node.name] = def,
      }
    }
    ---- Update all incoming links
    local old_process_len = string.len(old_process:url())
    for _, inlet in ipairs(self.node.slots.inlets) do
      local url = process:url() .. string.sub(inlet:url(), old_process_len + 1)
      for _,link in ipairs(inlet.links) do
        local node = link.source.node
        lk.deepMerge(changed_processes, node.process, {
          nodes = {
            [node.name] = {
              links = {
                [link.source.name] = {
                  -- remove old link
                  [inlet:url()] = false,
                  -- create new link
                  [url] = true,
                }
              }
            }
          }
        })
      end
    end
    ---- Update all views
    local base_url = old_process:url() .. '/' .. node.name .. '/'
    local new_url  = process:url() .. '/' .. node.name .. '/'
    local base_url_len = string.len(base_url)
    for view_name, view in pairs(self.zone.views) do
      for wid_id, widget in pairs(view.cache) do
        local connect = widget.connect
        -- connect:
        --   s:
        --     min: 0
        --     url: /a/three/_/x
        --     max: 1
        if connect then
          for dir, def in pairs(connect) do
            if def then
              target = def.url
              if string.sub(target, 1, base_url_len) == base_url then
                -- Update
                local new_target = new_url .. string.sub(target, base_url_len + 1)
                lk.deepMerge(changed_processes, self.zone.morph, {
                  _views = {
                    [view_name] = {
                      [wid_id] = {
                        connect = {
                          [dir] = {
                            url = new_target,
                          }
                        }
                      }
                    }
                  }
                })
              end
            end
          end
        end
      end
    end

    -- Execute receipt
    for p, def in pairs(changed_processes) do
      p:change(def)
    end
  else
    -- Process did not change: simply move back.
    local zone = self.node.process.zone
    local pv = zone.process_view_under
    zone.process_view_under = nil
    if pv then pv:update() end

    node.dragging = false
    local ghost_x, ghost_y = node.ghost:position()
    node:change {
      x = node_x,
      y = node_y,
    }
  end -- node.process ~= process
end
