--[[------------------------------------------------------

  _control.lk.Slider test
  -----------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('_control.lk.Slider')
local withUser = should:testWithUser()

function should.autoload()
  assertType('table', _control.lk.Slider)
end

local Slider = _control.lk.Slider

function should.createConnectors()
  local s = Slider('foo')
  local x = s.conn_s
  assertEqual('editor.Connector', x.type)
end

function should.findConnector()
  local slider = Slider('foo')
  local s = slider:connector('s')
  assertEqual('editor.Connector', s.type)
end

local function mockCtrl()
  return editor.Control()
end

local function mockZone()
  local self = {online = true}
  function self.findProcess()
    return self
  end
  self.findNode = self.findProcess
  self.push = self
  function self.connectConnector()
  end
  return self
end

function withUser.should.showSlider(t)
  local zone = mockZone()
  local s = Slider('foo')
  local url = '/a/metro/_/tempo'
  -- This is how we enable the control.
  s.conn_s:set({
    url = url,
    min = 0,
    max = 100,
  }, zone)

  -- mock network notification
  function zone:send(url, changes)
    local v = changes.nodes.metro._.tempo
    s.conn_s.changed(v)
    if v == 0 then
      t.continue = true
    end
  end
  s:show()
  t:timeout(function()
    return t.continue
  end)
  assertEqual(0, s.conn_s.value)
end

test.all()

