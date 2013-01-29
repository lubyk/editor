--[[------------------------------------------------------

  _control.lk.Select
  ------------------

  The select switch returns a single integer value.

--]]------------------------------------------------------
local lib = lk.SubClass(editor.Control)
_control.lk.Select = lib

-- default select size and options
local const = {
  DEFAULT = {w = 80, h = 40},
}
lib.const = const

function lib:init(id, view)
  self:initControl(id, view)
  self:setupConnectors {
    s = 'selection',
  }
  self.range    = nil
  self.no_range = true
  self:resize(const.DEFAULT.w, const.DEFAULT.h)
end

function lib:resized(w, h)
  self.w = w
  self.h = h
  -- compute option count and direction from size
  if w > h then
    self.dir = 'Horizontal'
    self.n = math.ceil(w/h)
  else
    self.dir = 'Vertical'
    self.n = math.ceil(h/w)
  end
end

local MouseMove = mimas.MouseMove

function lib:control(x, y, typ)
  if typ == 'release' then return end
  local v
  local cs = self.conn_s
  -- Detect click position to get value.
  if self.dir == 'Horizontal' then
    v = math.ceil(x * self.n / self.w)
  else
    v = math.ceil((self.h - y) * self.n / self.h)
  end
  if typ == MouseMove and v == cs.remote_value then return end
  cs.change(v)
end

local noBrush = mimas.NoBrush
local noPen   = mimas.NoPen

function lib:paintControl(p, w, h)
  local cs = self.conn_s
  local fill_sz
  local fill_pos
  if self.dir == 'Horizontal' then
    fill_sz = self.w / self.n
    fill_pos = (cs.remote_value-1) * fill_sz
    p:fillRect(fill_pos, 0, fill_sz, h, self.fill_color)
    if self.show_thumb then
      -- thumb
      local thumb_pos = (cs.value-1) * fill_sz
      p:fillRect(thumb_pos, 0, fill_sz, h, self.thumb_color)
    end

    -- option separation
    p:setPen(1, self.fill_color)
    for i = 1,self.n - 1 do
      local x = fill_sz * i
      p:drawLine(x, 0, x, h)
    end
  else
    fill_sz = self.h / self.n
    fill_pos = cs.remote_value * fill_sz
    p:fillRect(0, h - fill_pos, w, fill_sz, self.fill_color)
    if self.show_thumb then
      -- thumb
      local thumb_pos = cs.value * fill_sz
      p:fillRect(0, h - thumb_pos, w, fill_sz, self.thumb_color)
    end
    
    -- option separation
    p:setPen(1, self.fill_color)
    for i = 1,self.n - 1 do
      local y = fill_sz * i
      p:drawLine(0, y, w, y)
    end
  end

  -- border
  p:setPen(self.pen)
  p:setBrush(noBrush)
  p:drawRect(0, 0, w, h)
end

