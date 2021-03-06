--[[------------------------------------------------------

  editor.SlotView
  ---------------

  The SlotView show a single slot (inlet or outlet).

--]]------------------------------------------------------
local lib = lk.SubClass(mimas.Widget)
editor.SlotView = lib

-- constants
local box_padding = 1
local hpen_width = 1 -- half pen width
local bp = hpen_width + box_padding -- full box padding
local arc_radius = 0
local text_hpadding = 10
local text_vpadding = 6
local pad  = bp + hpen_width -- padding for inner shape (top/left)
local SLOTW = 8
local SLOTH = 5
local SLOT_PADDING = 10 -- space between slots
local START_DRAG_DIST = 4
local LINK_DISTANCE = 100

-- Needed by NodeView and LinkView
lib.SLOTW = SLOTW
lib.SLOTH = SLOTH
lib.SLOT_PADDING = SLOT_PADDING

function lib:init(slot)
  self:setToolTip(slot.name)
  self.type = slot.type
  self.slot = slot
  self.node = slot.node
  self.zone = slot.node.zone
  self:resize(SLOTW, SLOTH)
end

-- local BG_VALUE = app.theme == mimas.Application.LIGHT_STYLE and 0.8 or 0.5

-- custom paint
function lib:paint(p, w, h)
--  p:setPen(mimas.NoPen)

  -- draw inlets
  local color

  if self.zone.closest_slot_view == self then
    color = self.node.color:colorWithSaturation(1)
  else
    color = self.node.color --:colorWith(BG_VALUE)
  end
  p:fillRect(0, 0, w, h, color)
end

local MousePress,       MouseRelease,       DoubleClick =
      mimas.MousePress, mimas.MouseRelease, mimas.DoubleClick

function lib:click(x, y, type, btn, mod)
  local slot = self.slot
  if type == MousePress then
    -- store position but only start drag when moved START_DRAG_DIST away
    self.click_position = {x = x, y = y}
  elseif type == MouseRelease then
    if slot.dragging then
      local other_view = self.zone.closest_slot_view
      -- create link
      slot.dragging = false
      if other_view then
        local other_slot = other_view.slot
        self.zone.closest_slot_view = nil
        other_view:update()
        if slot.type == 'editor.Inlet' then
          slot, other_slot = other_slot, slot
        end
        local url = lk.absToRel(other_slot:url(), slot.node.parent:url())
        slot.node:change {
          links = {
            [slot.name] = {
              [url] = true
            }
          }
        }
      else
        -- aborted link creation
      end

      self.ghost.link_view:delete()
      self.ghost = nil
    end
  end
end

local function manhattanDist(a, b)
  return math.abs(b.x - a.x) + math.abs(b.y - a.y)
end

local function makeGhostLink(self)
  local slot = self.slot
  self.ghost = {
    slot_view = editor.SlotView(slot)
  }
  if slot.type == 'editor.Inlet' then
    self.ghost.link_view = editor.LinkView(self.ghost.slot_view, self)
  else
    self.ghost.link_view = editor.LinkView(self, self.ghost.slot_view)
  end

  -- We add the slot in the main view in case it is used for
  -- inter-process linking.
  slot.node.process.zone.view:addLinkView(self.ghost.link_view)
  self.ghost.link_view:lower()
end

function lib:mouse(x, y)
  local slot = self.slot
  if self.click_position and not slot.dragging and manhattanDist(self.click_position, {x=x,y=y}) > START_DRAG_DIST then
    -- start drag operation: create ghost Link
    slot.dragging = true
    makeGhostLink(self)
  end

  if self.ghost then
    local gx, gy = self:globalPosition()
    gx = gx + x
    gy = gy + y
    local view, d = self.node.process.zone:closestSlotView(gx, gy, self.type, slot.node)
    local old_closest = self.zone.closest_slot_view
    if view and d < LINK_DISTANCE then
      self.zone.closest_slot_view = view
      if old_closest ~= view then
        if old_closest then
          old_closest:update()
        end
        local gx, gy = view:globalPosition()
        -- To make usre it is moved
        app:hideToolTip()
        app:showToolTip(gx, gy, view.slot.name)
        view:update()
      end
    elseif old_closest then
      self.zone.closest_slot_view = nil
      old_closest:update()
    end

    self.ghost.slot_view:globalMove(gx - SLOTW/2, gy - SLOTH/2)
    self.ghost.link_view:slotMoved()
  end
end
