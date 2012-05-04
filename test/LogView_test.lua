--[[------------------------------------------------------

  editor.LogView test
  -------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.LogView')
local withUser = should:testWithUser()

function withUser.should.displayWindow(t)
  local l = editor.LogView()
  for i=1,10 do
    l:addMessage(
      string.format('/a/bob%i',i),
      'error', [[
    stdin:1: attempt to index global 'yaml' (a nil value)
    stack traceback:
    stdin:1: in main chunk
    [C]: ?
    Blah blah
    ]])
    l:addMessage(
      string.format('/a/bob%i',i),
      'info', 'hello world')
    l:addMessage(
      string.format('/a/bob%i',i),
      'warn', 'warning')
  end
  local start = elapsed()
  t.loop = lk.Timer(500, function()
    l:addMessage('/a/bob', 'info', string.format('hello world %.2f', (elapsed() - start)/1000))
  end)
  t.loop:start()

  l:show()

  function l:closed()
    t.continue = true
    t.loop = nil
  end
  
  t:timeout(10000, function()
    return t.continue
  end)
end


test.all()

