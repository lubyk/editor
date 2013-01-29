--[[------------------------------------------------------

  editor.Link
  -----------

  The Link contains a reference to the source and the
  target. When the target cannot be found, the link points
  to a "floating" inlet (inlet not connected to a Node).

--]]------------------------------------------------------

local lib   = {type='editor.Link'}
lib.__index = lib
editor.Link = lib

setmetatable(lib, {
  --- Create a new editor.Link reflecting the content of a remote
  -- link. If the process view is not shown, the LinkView is not
  -- created.
 __call = function(base, source, target, target_url, link_def)
  local self = {
    source  = source,
    target  = target,
    target_url = target_url,
    link_type = link_def.type,
  }
  
  -- register in source and target
  table.insert(target.links, self)
  table.insert(source.links, self)
  source.links_by_target[target_url] = self
  setmetatable(self, lib)
  return self
end})

function lib:set(def)
  -- changed definition
  self.link_type = def.type or self.link_type
  if self.view then
    -- Rebuild path in case link_type has changed
    self.view:slotMoved()
  end
end

function lib:updateView()
  if not self.view and self.target.view and self.source.view then
    -- Create link view
    self.view = editor.LinkView(self.source.view, self.target.view, self.link_type)
    if self:isCrossProcess() then
      self.source.node.process.zone.view:addLinkView(self.view)
    else
      self.source.node.process.view:addWidget(self.view)
      self.view:show()
    end
    self.view:lower() -- send to back
  end

  if self.view then
    self.view:slotMoved()
  end

  -- ghost
  if not self.ghost then
    if self.source.view and self.target.ghost then
      self.ghost = editor.LinkView(self.source.view, self.target.ghost)
    elseif self.source.ghost then
      self.ghost = editor.LinkView(self.source.ghost, self.target.view)
    end
    if self.ghost then
      self.source.node.process.zone.view:addLinkView(self.ghost)
    end
  elseif not self.source.ghost and not self.target.ghost then
    -- remove our ghost link
    self.ghost:delete()
    self.ghost = nil
  end

  if self.ghost then
    self.ghost:slotMoved()
  end
end

local function removeFromList(self, links)
  for i, link in ipairs(links) do
    if link == self then
      table.remove(links, i)
      break
    end
  end
end

-- called from Outlet (source)
function lib:delete()
  lk.log('delete', self.target_url)
  removeFromList(self, self.source.links)
  local link = self.source.links_by_target[self.target_url]
  if link == self then
    self.source.links_by_target[self.target_url] = nil
  end
  removeFromList(self, self.target.links)
  self:deleteView()
end

function lib:deleteView()
  lk.log('deleteView', self.view)
  if self.view then
    local zone = self.source.node.zone
    if zone.selected_link_view == self.view then
      zone.selected_link_view = nil
    end
    self.view:hide()
    self.view:delete()
    self.view = nil
  end
  if self.ghost then
    self.ghost:delete()
    self.ghost = nil
  end
end

function lib:isCrossProcess()
  return self.source.node.process ~= self.target.node.process
end
