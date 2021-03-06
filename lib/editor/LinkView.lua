--[[------------------------------------------------------

  editor.LinkView
  ---------------

  The LinkView show a single link between an outlet and an
  inlet.

--]]------------------------------------------------------
local lib = lk.SubClass(mimas.Widget)
editor.LinkView = lib
-- constants
local HPEN_WIDTH = 1 -- half pen width
local SLOTW = editor.SlotView.SLOTW
local SLOTH = editor.SlotView.SLOTH
local VECV  = 80      -- force vertical start/end
local PADV  = VECV/3  -- vertical pad needed to draw up/down curve when
                         -- outlet is lower from inlet
local GHOST_ALPHA = 0.3
local CLICK_DISTANCE = 15 -- how far do we still touch the link with the mouse
local BIDIRECTIONAL_WIDTH = 3 -- how wide should the bi-directional link be
local PADH = HPEN_WIDTH + BIDIRECTIONAL_WIDTH/2 -- keep some space for BIDIRECTIONAL_WIDTH

link_count = 0
function lib:init(source, target, link_type)
  self.source = source
  self.target = target
  self.outlet = source.slot
  if not target then
    lk.log(debug.traceback())
  end
  self.inlet  = target.slot
  self.zone = source.slot.node.zone
  self.link_type = link_type
  -- cache
  self.pen = mimas.Pen(2 * HPEN_WIDTH, self.outlet.node.color)

  self:slotMoved()
end

local function makePath(type, x1, y1, x2, y2)
  local path = mimas.Path()
  path:moveTo(x1, y1)
  local vect = math.min(VECV, math.abs(x2 - x1)*0.3 + VECV*0.1);
  vect = math.min(vect, math.abs(y2 - y1) + VECV*0.1);

  path:cubicTo(
    x1, y1 + vect,
    x2, y2 - vect,
    x2, y2
  )
  if type == 'Bidirectional' then
    local outline = path:outlineForWidth(CLICK_DISTANCE)
    path = path:outlineForWidth(BIDIRECTIONAL_WIDTH)
    return path, outline
  else
    return path, path:outlineForWidth(CLICK_DISTANCE)
  end
end

-- must be called whenever a slot (or a NodeView/Patch) is moved.
function lib:slotMoved()
  -- global start position
  local x1, y1 = self.source:globalPosition()
  x1 = x1 + SLOTW/2
  y1 = y1 + SLOTH
  -- global end position
  local x2, y2 = self.target:globalPosition()
  x2 = x2 + SLOTW/2
  -- global position of this widget
  local x = math.min(x1, x2) - PADH
  local y = math.min(y1, y2) - PADV
  local w = math.abs(x2 - x1) + 2*PADH
  local h = math.abs(y2 - y1) + 2*PADV
  self.path, self.outline = makePath(self.link_type, x1 - x, y1 - y, x2 - x, y2 - y)
  -- own global position
  self:globalMove(x, y)
  self:resize(w, h)
  -- force redraw in case we do not move but are
  -- in the end of a drag operation (ghost looking)
  self:lower()
  self:update()
end

local White = mimas.colors.Red:colorWithAlpha(0.5)
-- custom paint
function lib:paint(p, w, h)
  local color = self.outlet.node.color
  if self.zone.selected_link_view == self then
    color = mimas.colors.White
  elseif self.source.is_ghost or self.target.is_ghost then
    color = color:colorWithAlpha(GHOST_ALPHA)
  end
  p:setPen(2*HPEN_WIDTH, color)

  p:drawPath(self.path)
end

function lib:delete()
  self.super:__gc()
end

local MousePress,       MouseRelease,       DoubleClick =
      mimas.MousePress, mimas.MouseRelease, mimas.DoubleClick

function lib:click(x, y, type)
  if self.outline:contains(x, y) then
    if type == DoubleClick then
      local slot = self.outlet
      -- remove link
      slot.node:change {
        links = {
          [slot.name] = {
            [self.inlet:url()] = false
          }
        }
      }
    else
      self.zone:selectLinkView(self)
    end
  else
    -- pass up
    return false
  end
end

function lib:resized(w, h)
  self.w = w
  self.h = h
end
