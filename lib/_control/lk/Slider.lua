--[[------------------------------------------------------

  _control.lk.Slider
  ------------------

  Async slider.

--]]------------------------------------------------------
local lib = lk.SubClass(editor.Control)
_control.lk.Slider = lib.new

-- default Slider size
local const = {
  DEFAULT      = {w = 40, h = 100},
  TEXT_PADDING = 5,
  THUMB_RATIO  = 20,
  THUMB_MAX    = 10,
}
lib.const = const

function lib:init(id, view)
  local mt = debug.getmetatable(self)
  self:initControl(id, view)
  self:setupConnectors {
    s = 'Slider value',
  }
  self:resize(const.DEFAULT.w, const.DEFAULT.h)
end

function lib:resized(w, h)
  self.w = w
  self.h = h
  self.is_horizontal = w > h
end

function lib:control(x, y)
  if typ == 'release' then return end
  local s
  if self.is_horizontal then
    s = x / self.w
  else
    local h = self.h
    s = (h - y) / h
  end
  self.conn_s.change(s)
  self:update()
end

local noBrush = mimas.NoBrush
local noPen   = mimas.NoPen
local ErrorColor    = editor.Control.ErrorColor
local DisabledColor = editor.Control.DisabledColor

function lib:paintControl(p, w, h)
  local cs = self.conn_s
  local rv = cs.remote_value
  if type(rv) ~= 'number' then
    if rv == nil then
      -- not set yet
      p:fillRect(0, 0, w, h, DisabledColor)
    else
      -- error
      p:fillRect(0, 0, w, h, ErrorColor)
    end
  else
    if self.is_horizontal then
      --=============================================== HORIZONTAL
      local s = rv * w
      p:fillRect(0, 0, s, h, self.fill_color)
      if self.show_thumb then
        -- thumb
        local t = cs.value * w
        local half_thumb = math.min(w / const.THUMB_RATIO, const.THUMB_MAX)
        p:setBrush(self.thumb_color)
        p:drawRect(t-half_thumb, 0, 2*half_thumb, h)
        -- show current value
        p:drawText(const.TEXT_PADDING, 0, w - const.TEXT_PADDING, h, mimas.AlignLeft + mimas.AlignVCenter, cs:printValue())
      end
    else
      --=============================================== VERTICAL
      local s = rv * h
      p:fillRect(0, h-s, w, s, self.fill_color)
      if self.show_thumb then
        -- thumb
        local t = (1 - cs.value) * h
        local half_thumb = math.min(h / const.THUMB_RATIO, const.THUMB_MAX)
        p:setBrush(self.thumb_color)
        p:drawRect(0, t-half_thumb, w, 2*half_thumb)
        -- show current value
        p:drawText(0, h - const.TEXT_PADDING - 20, w, 20, mimas.AlignCenter, cs:printValue())
      end
    end
  end


  -- border
  p:setPen(self.pen)
  p:setBrush(noBrush)
  p:drawRect(0, 0, w, h)
end

