--[[------------------------------------------------------

  editor.Connector test
  ---------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.Connector')

function should.autoload()
  assertType('table', editor.Connector)
end

function should.setType()
  local conn = editor.Connector({}, 'x')
  assertEqual('editor.Connector', conn.type)
end

function should.callbackCtrlOnChanged()
  local ctrl = {}
  local res
  function ctrl:changed(...)
    res = {...}
  end
  local conn = editor.Connector(ctrl, 'x')
  conn.url = '/foobar'
  conn:set({url=conn.url}, {})
  -- ! No 'self' here.
  conn.changed(4.55)
  assertValueEqual({
    'x',
    4.55,
  }, res)
end

local function mockCtrl()
  return editor.Control()
end

local function mockZone()
  local self = {}
  function self.findProcess()
    return self
  end
  self.findNode = self.findProcess
  function self.connectConnector()
  end
  return self
end

function should.connectOnSet(t)
  local ctrl = mockCtrl()
  local zone = mockZone()
  function zone:connectConnector()
    t.connected = true
  end
  local url = '/foo/a/b/_/foo'
  local conn = editor.Connector(ctrl, 'x')
  conn:set({url=url}, zone)
  assertTrue(t.connected)
end

function should.pushchange()
  local ctrl = mockCtrl()
  local zone = mockZone()
  function zone:connectConnector()
  end
  -- When mocking the process
  zone.online = true
  -- process.push
  zone.push = zone
  local res
  function zone:send(url, val)
    res = val
  end
  local url = '/foo/a/b/_/foo'
  local conn = editor.Connector(ctrl, 'x')
  conn:set({url=url}, zone)
  conn.change(12.33)
  assertValueEqual({
    nodes = {
      a = {
        b = {
          _ = {
            foo = 12.33,
          },
        },
      },
    },
  }, res)
end


test.all()

