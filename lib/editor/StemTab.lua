--[[------------------------------------------------------

  editor.StemTab
  --------------

  Representation of a stem cell in the machine list view.

  The StemTab is shown as a plus sign and can be drag &
  dropped to create new processes on the given machine.

--]]------------------------------------------------------
local lib = lk.SubClass(mimas.Widget)
editor.StemTab = lib
lib.type = 'editor.StemTab'
-- Sort in MachineView
lib.sort = 10 -- last
local private = {}

-- CONSTANTS
local MousePress, MouseRelease = mimas.MousePress, mimas.MouseRelease
local START_DRAG_DIST = 4
local PEN_WIDTH       = 2
local EDIT_WIDTH = 80
local EDIT_PADDING = 3
local MAX_WAIT_MS = 8

function lib:init(stem)
  self.process = stem
  self.name = stem.name
  self:setTitle(stem.title)
  self.machine = stem.machine
  self.zone = self.machine.zone

  self.text_pen = mimas.Pen(1, mimas.Color(0, 0, 1))
  self.pen = mimas.Pen(PEN_WIDTH, mimas.Color(0.3, 0.3, 0.8, 0.5), mimas.DotLine)
  self.brush = mimas.Brush(mimas.Color(0.3, 0.3, 0.3, 0.5))
end

lib.setTitle     = editor.ProcessTab.setTitle
lib.paint        = editor.ProcessTab.paint
lib.setAlignment = editor.ProcessTab.setAlignment

local       RightButton,       MetaModifier  = 
      mimas.RightButton, mimas.MetaModifier

function lib:click(x, y, op, btn, mod)
  if op == MousePress and
     (btn == RightButton or mod == MetaModifier) then
    local sx, sy = self:globalPosition()
    private.showContextMenu(self, sx + x, sy + y)
  elseif op == MousePress then
    self.click_position = {x=x,y=y}
    local gx, gy = self:globalPosition()
    self.base_pos = {gx = gx, gy = gy}
  elseif op == MouseRelease then
    if self.dragging then
      -- drop
      self.dragging = false
      local gx, gy = self.ghost:globalPosition()
      local px, py = self.zone.view.patch_view:globalPosition()
      self.ghost.def = {
        x   = gx - px,
        y   = gy - py,
        hue = self.ghost.process.hue,
        w   = self.ghost.w,
        h   = self.ghost.h,
      }
      -- Ask for name and create new process
      self.ghost.lbl_w = EDIT_WIDTH - 10
      self.ghost:update()
      local edit = mimas.LineEdit()
      self.edit  = edit
      function edit.keyboard(edit, key, on)
        if on and key == mimas.Key_Escape then
          -- abort
          edit.editingFinished = nil
          self.edit:hide()
          self.ghost:hide()
          self.ghost = nil
          return
        end
        -- Normal processing
        return true
      end

      self.ghost:addWidget(edit)
      edit:resize(EDIT_WIDTH, self.min_height - EDIT_PADDING)
      edit:move(2*EDIT_PADDING, EDIT_PADDING)
      edit:show()
      edit:setFocus()

      function edit.editingFinished(edit, name)
        if name == '' then
          if self.ghost then
            self.ghost:hide()
            self.ghost = nil
          end
        else
          self.ghost:setName(name)
          self.ghost.def.name = name
          -- Make sure it is not called a second time
          edit.editingFinished = nil
          edit:hide()
          self.edit = nil

          -- Blink while waiting
          local ghost = self.ghost
          ghost:animate(MAX_WAIT_MS, function()
            ghost:hide()
            if ghost == self.ghost then
              self.ghost = nil
            end
          end)

          -- Remove ghost on process connection
          self.zone:onProcessConnected(name, function()
            ghost.thread = nil
            ghost:hide()
            self.ghost = nil
          end)

          -- Ask machine to create process
          self.machine:createProcess(self.ghost.def)
        end
      end
    end
  end
end

local function manhattanDist(a, b)
  return math.abs(b.x - a.x) + math.abs(b.y - a.y)
end

function lib:mouse(x, y)
  local zone = self.zone
  local view = zone.view
  if self.click_position and not self.dragging and manhattanDist(self.click_position, {x=x,y=y}) > START_DRAG_DIST then
    -- start drag operation: self becomes ghost
    self.dragging = true
    self.ghost = editor.ProcessView { name = '', hue = math.random(), nodes = {}, pending_inlets = {}, zone = zone }
    self.ghost.is_ghost = true
    self.ghost:resize(200, 200)
    view:addWidget(self.ghost)
    self.ghost:show()
  end

  if self.dragging then
    -- dragging
    local gx = self.base_pos.gx + x - self.click_position.x
    local gy = self.base_pos.gy + y - self.click_position.y
    self.ghost:globalMove(gx, gy)
  end
end

function private:showContextMenu(gx, gy)
  local menu = mimas.Menu('')
  if self.menu and not menu:deleted() then
    self.menu:hide()
  end
  self.menu = menu

  menu:addAction('Stop', '', function()
    self.process:quit()
  end)
  menu:popup(gx - 5, gy - 5)
end

