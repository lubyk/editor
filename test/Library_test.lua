--[[------------------------------------------------------

  editor.Library
  --------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.Library')

function should.loadCode()
  assertTrue(editor.Library)
end

local function makeLib()
  local op
  local lib = editor.Library {
    db = sqlite3.open_memory(),
    table_name = 'nodes',
    sources = {
      fixture.path('_prototypes'),
    },
  }
  lib:sync()
  return lib
end

function should.populateDatabase()
  local lib = makeLib()
  assertEqual(3, lib:nodeCount())
end

function should.findNodeByPosition()
  local lib = makeLib()
  local node = lib:node(1)
  assertMatch('Does nothing', node.code)
  node.code = nil
  assertValueEqual({
    path = 'test/fixtures/_prototypes/foo/Bar.lua',
    name = 'foo.Bar',
    keywords = 'machine blah xy foo.Bar',
  }, node)
  assertValueEqual('foo.Baz', lib:node(2).name)
end

function should.findWithFilter()
  local lib = makeLib()
  assertValueEqual('foo.Baz', lib:node('salad').name)
end

function should.findCodeByName()
  local lib = makeLib()
  assertMatch('Does a great fruit salad.', lib:code('foo.Baz'))
end

function should.notAddPercentInFilter()
  local lib = makeLib()
  assertNil(lib:node('Bar%'))
end

function should.paginateWithFilter()
  local lib = makeLib()
  assertValueEqual('foo.Bar', lib:node('foo').name)
  assertValueEqual('foo.Baz', lib:node('foo', 2).name)
end

function should.returnNilOnNotFound()
  local lib = makeLib()
  assertEqual(nil, lib:node('xx'))
end

test.all()
