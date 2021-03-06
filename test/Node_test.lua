--[[------------------------------------------------------

  editor.Node test
  ----------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.Node')

-- Mock a process without network connectivity
local function patch(name)
  local instance = {
    name           = name,
    nodes          = {},
    pending_inlets = {}
  }
  setmetatable(instance, editor.Process)
  return instance
end

function should.createNode()
  local process = patch('dummy')
  local node = editor.Node {
    process = process,
    hue     = 0.5,
  }
  assertEqual(0.5, node.hue)
  assertEqual('editor.Node', node.type)
end

function should.returnFilePath()
  local process = patch('dummy')
  local node = editor.Node {
    name    = 'buz',
    process = process
  }
  assertMatch('.lk_editor/dummy/buz.lua', node:filepath())
end

function should.createOutlets()
  local process = patch('dummy')
  local node = editor.Node {
    process = process,
    outlets = {
      {name = 'a'}
    }
  }
  assertEqual('editor.Outlet', node.outlets.a.type)
end

function should.createInlets()
  local process = patch('dummy')
  local node = editor.Node {
    process = process,
    inlets = {
      {name = 'a'}
    }
  }
  assertEqual('editor.Inlet', node.inlets.a.type)
end

function should.usePendingInlets()
  local process = patch('dummy')
  process.pending_inlets.foo = {}
  -- create pending Inlet
  local inlet = editor.Inlet(process.pending_inlets.foo, 'a')
  local node = editor.Node {
    process = process,
    name    = 'foo',
    inlets = {
      {name = 'a'}
    }
  }
  assertNil(process.pending_inlets.foo)
  assertEqual('editor.Inlet', node.inlets.a.type)
  assertEqual(inlet, node.inlets.a)
end

test.all()
