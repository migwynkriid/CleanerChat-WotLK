-- Glass WoW 3.3.5 Compatibility Layer
-- Provides polyfills for missing APIs in WotLK

local _G = _G

---
-- Detect if we're on native 3.3.5 vs Ascension/custom servers
-- Ascension has retail-backported APIs; native 3.3.5 does not
local isNative335 = true  -- Assume native 3.3.5 by default

-- Check for Ascension/custom server features (retail-backported APIs)
-- These APIs exist on Ascension but not on vanilla 3.3.5 servers
if _G.C_ClassTalents or _G.C_Spell or _G.GetSpecialization or
   _G.C_CurrencyInfo or _G.C_MythicPlus or _G.C_AzeriteEmpoweredItem then
  isNative335 = false
end

-- Also check if BackdropTemplate actually exists as a real template
-- On Ascension, this is defined by Blizzard; on native 3.3.5 it's not
-- We test by checking if CreateFrame with BackdropTemplate would work
-- (Don't actually create to avoid side effects - just check the global)
if _G.BACKDROP_DIALOG_32_32 or _G.BACKDROP_TOOLTIP_16_16_5555 then
  isNative335 = false  -- These backdrop constants exist on Ascension/retail
end

-- Expose for debugging and other code that might need it
_G.GLASS_IS_NATIVE_335 = isNative335

---
-- BackdropTemplate compatibility for native 3.3.5.
-- In native 3.3.5, BackdropTemplate doesn't exist as an XML template (frames
-- have SetBackdrop built-in natively), so any CreateFrame call that inherits
-- "BackdropTemplate" -- as the embedded AceGUI widgets do -- would error. This
-- wrapper strips it back out.
local originalCreateFrame = _G.CreateFrame
local function GlassCreateFrame(frameType, name, parent, template, id)
  -- On native 3.3.5, strip out BackdropTemplate since it doesn't exist
  if isNative335 and template then
    -- Handle both standalone "BackdropTemplate" and comma-separated lists
    if template == "BackdropTemplate" then
      template = nil
    elseif type(template) == "string" then
      -- Remove "BackdropTemplate" from comma-separated template list
      template = template:gsub("BackdropTemplate%s*,%s*", "")
      template = template:gsub("%s*,%s*BackdropTemplate", "")
      template = template:gsub("^BackdropTemplate$", "")
      if template == "" then template = nil end
    end
  end
  return originalCreateFrame(frameType, name, parent, template, id)
end

-- Only install the wrapper globally on native 3.3.5. On Ascension/custom
-- servers BackdropTemplate already exists, so overwriting the secure global
-- CreateFrame would only taint protected frames (e.g. CompactPartyFrame).
if isNative335 then
  _G.CreateFrame = GlassCreateFrame
end

---
-- CRITICAL: BackdropTemplateMixin must be defined FIRST
-- Ascension's shared libraries check for this before addon code runs
-- Must be a proper table with backdrop methods (not just empty)
if not _G.BackdropTemplateMixin then
  _G.BackdropTemplateMixin = {
    -- OnBackdropLoaded is called by the BackdropTemplate
    OnBackdropLoaded = function(self)
      -- No-op: WotLK frames already support SetBackdrop natively
    end,
    -- OnBackdropSizeChanged is called when the frame is resized
    OnBackdropSizeChanged = function(self)
      -- No-op: WotLK handles this automatically
    end,
    -- ApplyBackdrop sets up the backdrop
    ApplyBackdrop = function(self)
      -- No-op: In WotLK, SetBackdrop is called directly
    end,
    -- These methods delegate to the native frame methods
    SetBackdrop = function(self, backdrop)
      if self.SetBackdrop then
        getmetatable(self).__index.SetBackdrop(self, backdrop)
      end
    end,
    SetBackdropColor = function(self, r, g, b, a)
      if self.SetBackdropColor then
        getmetatable(self).__index.SetBackdropColor(self, r, g, b, a)
      end
    end,
    SetBackdropBorderColor = function(self, r, g, b, a)
      if self.SetBackdropBorderColor then
        getmetatable(self).__index.SetBackdropBorderColor(self, r, g, b, a)
      end
    end,
    GetBackdrop = function(self)
      if self.GetBackdrop then
        return getmetatable(self).__index.GetBackdrop(self)
      end
    end,
    GetBackdropColor = function(self)
      if self.GetBackdropColor then
        return getmetatable(self).__index.GetBackdropColor(self)
      end
    end,
    GetBackdropBorderColor = function(self)
      if self.GetBackdropBorderColor then
        return getmetatable(self).__index.GetBackdropBorderColor(self)
      end
    end,
  }
end

---
-- Mixin polyfill
-- Copies methods from mixins to the target object
if not _G.Mixin then
  function _G.Mixin(target, ...)
    for i = 1, select("#", ...) do
      local mixin = select(i, ...)
      if mixin then
        for key, value in pairs(mixin) do
          target[key] = value
        end
      end
    end
    return target
  end
end

---
-- MouseIsOver polyfill
-- Checks if the mouse is currently over a frame
if not _G.MouseIsOver then
  function _G.MouseIsOver(frame, topOffset, bottomOffset, leftOffset, rightOffset)
    if not frame:IsVisible() then
      return false
    end
    
    topOffset = topOffset or 0
    bottomOffset = bottomOffset or 0
    leftOffset = leftOffset or 0
    rightOffset = rightOffset or 0
    
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    x, y = x / scale, y / scale
    
    local left, bottom, width, height = frame:GetRect()
    if not left then return false end
    
    local right = left + width
    local top = bottom + height
    
    left = left + leftOffset
    right = right - rightOffset
    top = top - topOffset
    bottom = bottom + bottomOffset
    
    return x >= left and x <= right and y >= bottom and y <= top
  end
end

---
-- CreateObjectPool polyfill
-- Simple object pooling implementation
if not _G.CreateObjectPool then
  function _G.CreateObjectPool(creationFunc, resetterFunc)
    local pool = {
      objects = {},
      activeObjects = {},
      creationFunc = creationFunc,
      resetterFunc = resetterFunc,
    }
    
    function pool:Acquire()
      local obj
      if #self.objects > 0 then
        obj = table.remove(self.objects)
      else
        obj = self.creationFunc(self)
      end
      self.activeObjects[obj] = true
      return obj
    end
    
    function pool:Release(obj)
      if self.activeObjects[obj] then
        self.activeObjects[obj] = nil
        if self.resetterFunc then
          self.resetterFunc(self, obj)
        end
        table.insert(self.objects, obj)
      end
    end
    
    function pool:ReleaseAll()
      for obj in pairs(self.activeObjects) do
        self:Release(obj)
      end
    end
    
    function pool:GetNumActive()
      local count = 0
      for _ in pairs(self.activeObjects) do
        count = count + 1
      end
      return count
    end
    
    return pool
  end
end

-- NOTE: C_Timer polyfill is handled in Core/Common/Compatibility.lua
-- It provides a global _G.C_Timer with pcall-protected callbacks to prevent
-- errors from buggy third-party addon callbacks (like MRT) from spamming logs.

---
-- SetColorTexture polyfill
-- In 3.3.5, we use SetTexture with solid color files or SetVertexColor
local frameMeta = getmetatable(CreateFrame("Frame")).__index

-- Create a test texture to get the texture metatable and add SetColorTexture directly
do
  local testFrame = CreateFrame("Frame")
  local testTexture = testFrame:CreateTexture()
  local textureMeta = getmetatable(testTexture)
  
  -- Add SetColorTexture to the texture metatable's __index
  if textureMeta and textureMeta.__index then
    local textureIndex = textureMeta.__index
    if type(textureIndex) == "table" and not textureIndex.SetColorTexture then
      textureIndex.SetColorTexture = function(self, r, g, b, a)
        -- Use solid white texture and tint it
        self:SetTexture("Interface\\Buttons\\WHITE8x8")
        self:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
      end
    end
  end
  
  -- Clean up test objects
  testTexture:Hide()
  testFrame:Hide()
end

-- Add SetColorTexture method to texture objects (fallback for edge cases)
local function AddSetColorTexture(texture)
  if texture and not texture.SetColorTexture then
    texture.SetColorTexture = function(self, r, g, b, a)
      -- Use solid white texture and tint it
      self:SetTexture("Interface\\Buttons\\WHITE8x8")
      self:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
  end
  return texture
end

-- Also provide a global helper for libraries that need it
_G.Glass_EnsureSetColorTexture = AddSetColorTexture

-- Don't override frameMeta.CreateTexture: doing so taints every texture the
-- game's secure code creates. SetColorTexture is already added to the texture
-- metatable above.

---
-- StopAnimating polyfill
-- Stops all animation groups on a frame
if not frameMeta.StopAnimating then
  frameMeta.StopAnimating = function(self)
    -- In 3.3.5, we need to manually stop known animation groups
    if self.showAg then
      self.showAg:Stop()
    end
    if self.hideAg then
      self.hideAg:Stop()
    end
    -- Generic approach - look for common animation group names
    local agNames = {"introAg", "outroAg", "fadeAg", "slideAg"}
    for _, name in ipairs(agNames) do
      if self[name] and self[name].Stop then
        self[name]:Stop()
      end
    end
  end
end

---
-- Hyperlink handling for 3.3.5
-- SetHyperlinksEnabled might work differently
local simpleFrameMeta = getmetatable(CreateFrame("Frame")).__index
if not simpleFrameMeta.SetHyperlinksEnabled then
  simpleFrameMeta.SetHyperlinksEnabled = function(self, enabled)
    -- In 3.3.5, hyperlinks are generally handled via event hooks
    -- This is a no-op placeholder
    self._hyperlinksEnabled = enabled
  end
end

---
-- SetIndentedWordWrap polyfill for FontStrings
-- This feature doesn't exist in 3.3.5, so we skip it
local fontStringMeta = getmetatable(UIParent:CreateFontString()).__index
if not fontStringMeta.SetIndentedWordWrap then
  fontStringMeta.SetIndentedWordWrap = function(self, enabled)
    -- Not available in 3.3.5, silent no-op
  end
end

---
-- GetLineHeight polyfill for FontStrings
-- In WotLK 3.3.5, FontStrings don't have GetLineHeight
if not fontStringMeta.GetLineHeight then
  fontStringMeta.GetLineHeight = function(self)
    -- Try to get font size from the font object
    local _, fontHeight = self:GetFont()
    if fontHeight and fontHeight > 0 then
      return fontHeight
    end
    -- Fallback: use GetStringHeight for single line or default
    local stringHeight = self:GetStringHeight()
    if stringHeight and stringHeight > 0 then
      return stringHeight
    end
    return 14  -- reasonable default
  end
end

---
-- Mask texture polyfills (not available in 3.3.5)
if not frameMeta.CreateMaskTexture then
  frameMeta.CreateMaskTexture = function(self)
    -- Return a dummy object that won't crash
    return {
      SetTexture = function() end,
      SetSize = function() end,
      SetPoint = function() end,
      Show = function() end,
      Hide = function() end,
    }
  end
end

local textureMeta = getmetatable(UIParent:CreateTexture()).__index
if not textureMeta.AddMaskTexture then
  textureMeta.AddMaskTexture = function(self, mask)
    -- Not available in 3.3.5, silent no-op
  end
end

---
-- Animation method polyfills (WotLK 3.3.5 has different animation API)
-- SetFromAlpha, SetToAlpha, SetSmoothing may not exist
do
  local testFrame = CreateFrame("Frame")
  local testAg = testFrame:CreateAnimationGroup()
  local testAnim = testAg:CreateAnimation("Alpha")
  
  if testAnim then
    local animMeta = getmetatable(testAnim).__index
    if animMeta then
      -- SetFromAlpha polyfill
      if not animMeta.SetFromAlpha then
        animMeta.SetFromAlpha = function(self, alpha)
          self._fromAlpha = alpha
          -- In WotLK, use SetChange for relative alpha change
          if self._toAlpha and self.SetChange then
            self:SetChange(self._toAlpha - alpha)
          end
        end
      end
      
      -- SetToAlpha polyfill
      if not animMeta.SetToAlpha then
        animMeta.SetToAlpha = function(self, alpha)
          self._toAlpha = alpha
          -- In WotLK, use SetChange for relative alpha change
          if self._fromAlpha and self.SetChange then
            self:SetChange(alpha - self._fromAlpha)
          elseif self.SetChange then
            -- Default: assume fading from 1 to alpha or from 0 to alpha
            self:SetChange(alpha - (self._fromAlpha or 0))
          end
        end
      end
      
      -- SetSmoothing polyfill
      if not animMeta.SetSmoothing then
        animMeta.SetSmoothing = function(self, smoothType)
          -- Not available in 3.3.5, silent no-op
        end
      end
    end
  end
end

---
-- FCF_GetNumActiveChatFrames polyfill
if not _G.FCF_GetNumActiveChatFrames then
  function _G.FCF_GetNumActiveChatFrames()
    local count = 0
    for i = 1, NUM_CHAT_WINDOWS do
      local frame = _G["ChatFrame"..i]
      if frame and frame:IsShown() then
        count = count + 1
      end
    end
    return count
  end
end

---
-- IsCombatLog polyfill
if not _G.IsCombatLog then
  function _G.IsCombatLog(chatFrame)
    return chatFrame == _G.ChatFrame2
  end
end
