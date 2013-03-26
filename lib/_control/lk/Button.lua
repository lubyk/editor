--[[------------------------------------------------------

  _control.lk.Button
  -------------------

  A button (sends bang on release).

--]]------------------------------------------------------
local lib = lk.SubClass(editor.Control)
_control.lk.Button = lib.new

-- default select size and options
local const = {
  PARAM_NAMES = {
    {'font_size', 'Font size'},
    {'nb_format', 'Number format'},
  },
  DEFAULT = {
    w = 80,
    h = 40,
    font_size = 16,
    nb_format = 2,
  },
}
lib.const = const

function lib:init(id, view)
  self.button = mimas.Button('Run')
  self:setFontSize(const.DEFAULT.font_size)
  self:addWidget(self.button)
  self.button:move(0,0)

  self:initControl(id, view)
  self:setupConnectors {
    s = 'print',
  }
  self.range    = nil
  self.no_range = true
  self:resize(const.DEFAULT.w, const.DEFAULT.h)
end

function lib:resized(w, h)
  self.w = w
  self.h = h
  self.button:resize(w, h)
end

function lib:setFontSize(p)
  self.button:setStyle(string.format([[
  font-size:%ipx;
  ]], p))
end

-- Set widget view parameters.
function lib:setParams(p)
  self:setHue(p.hue)
  self:setFontSize(p.font_size*1)
  self.nb_format = string.format("%%.%if", p.nb_format)
end

local BORDER_SAT = app.theme.style == 'light' and 0.8 or 0.3

function lib:setHue(h)
  editor.Control.setHue(self, h)
  if self.enabled then
    self.pen = mimas.Pen(2, mimas.Color(self.hue, 0.6, BORDER_SAT))
    self.fill_color = app.theme._background
  end
end

local MouseMove = mimas.MouseMove

function lib:control(x, y, typ)
  -- noop
end

local noBrush = mimas.NoBrush
local noPen   = mimas.NoPen
local Align = mimas.AlignLeft + mimas.AlignVCenter

function lib:paintControl(p, w, h)
  local v = self.conn_s.remote_value
  if type(v) == 'number' then
    v = string.format(self.nb_format, v)
  elseif v then
    v = tostring(v)
  else
    v = ''
  end
  if v ~= self.last_v then
    self.last_v = v
    self.button:setText(v)
  end
  -- border
  -- p:fillRect(0, 0, w, h, self.fill_color)
  -- p:setPen(self.pen)
  -- p:setBrush(noBrush)
  -- p:drawRect(0, 0, w, h)
end

