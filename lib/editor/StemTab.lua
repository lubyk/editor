--[[------------------------------------------------------

  editor.StemTab
  --------------

  Representation of a stem cell in the machine list view.

  The StemTab is shown as a plus sign and can be drag &
  dropped to create new processes on the given machine.

--]]------------------------------------------------------
local lib = lk.SubClass(mimas, 'Widget')
editor.StemTab = lib

-- CONSTANTS
local MousePress, MouseRelease = mimas.MousePress, mimas.MouseRelease
local START_DRAG_DIST = 4
local PEN_WIDTH       = 2
local EDIT_WIDTH = 80
local EDIT_PADDING = 3
local MAX_WAIT_MS = 16000

function lib:init(service)
  self.service = service
  self.service_name = service.name
  self:setName('+')
  self.machine = service.machine
  self.machine:setStem(service)
  self.zone    = self.machine.zone

  self.pen   = mimas.Pen(PEN_WIDTH, mimas.Color(0.3, 0.3, 0.8, 0.5), mimas.DotLine)
  self.brush = mimas.Brush(mimas.Color(0.3, 0.3, 0.3, 0.5))
end

lib.setName = editor.ProcessTab.setName
lib.paint   = editor.ProcessTab.paint

function lib:click(x, y, op, btn, mod)
  if op == MousePress then
    self.click_position = {x=x,y=y}
    local gx, gy = self:globalPosition()
    self.base_pos = {gx = gx, gy = gy}
  elseif op == MouseRelease then
    if self.dragging then
      -- drop
      self.dragging = false
      local gx, gy = self.ghost:globalPosition()
      local px, py = self.zone.main_view.patching_view:globalPosition()
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
      self.edit = mimas.LineEdit()
      self.ghost:addWidget(self.edit)
      self.edit:resize(EDIT_WIDTH, self.min_height - EDIT_PADDING)
      self.edit:move(2*EDIT_PADDING, EDIT_PADDING)
      self.edit:setFocus()
      function self.edit.editingFinished(edit, name)
        self.ghost:setName(name)
        self.ghost.def.name = name
        -- Make sure it is not called a second time
        self.edit.editingFinished = nil
        self.edit:hide()
        self.edit = nil
        -- TODO: keep ghost visible for some time and blink until it becomes real
        local ghost = self.ghost
        ghost.thread = lk.Thread(function()
          local start_time = worker:now()
          local t = 0
          local i = 0
          while t <= MAX_WAIT_MS do
            i = i + 1
            sleep(50)
            t = worker:now() - start_time
            ghost:animate(t)
          end
          ghost.thread = nil
          ghost:hide()
          self.ghost = nil
        end)
        self.zone:onAddProcess(name, function()
          ghost.thread = nil
          ghost:hide()
          self.ghost = nil
        end)
        self.machine:createProcess(self.ghost.def)
      end
    end
  end
end

local function manhattanDist(a, b)
  return math.abs(b.x - a.x) + math.abs(b.y - a.y)
end

function lib:mouse(x, y)
  local zone = self.zone
  local main_view = zone.main_view
  if self.click_position and not self.dragging and manhattanDist(self.click_position, {x=x,y=y}) > START_DRAG_DIST then
    -- start drag operation: self becomes ghost
    self.dragging = true
    self.ghost = editor.ProcessView { name = '', hue = math.random(), nodes = {}, pending_inlets = {}, delegate = zone }
    self.ghost.is_ghost = true
    self.ghost:resize(EDIT_WIDTH + 20,100)
    main_view:addWidget(self.ghost)
  end

  if self.dragging then
    -- dragging
    local gx = self.base_pos.gx + x - self.click_position.x
    local gy = self.base_pos.gy + y - self.click_position.y
    self.ghost:globalMove(gx, gy)
  end
end










