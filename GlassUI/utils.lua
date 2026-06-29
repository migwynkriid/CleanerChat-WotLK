local Core, _, Utils = unpack(select(2, ...))

-- Utility functions

---
-- Print to VDT
Utils.print = function (str, t)
  if _G.ViragDevTool_AddData then
    _G.ViragDevTool_AddData(t, str)
  else
    -- Buffer print messages until ViragDevTool loads
    table.insert(Core.printBuffer, {str, t})
  end
end

---
-- Prints Glass' notification messages
Utils.notify = function (message)
  print("|c00DFBA69Glass|r: ", message)
end

---
-- Set a solid-colour texture (WotLK 3.3.5 compatible). SetColorTexture is
-- polyfilled in compat.lua, but some objects/paths may still lack it, so fall
-- back to a tinted white texture. Centralizes the SetSolidColor helper that was
-- copy-pasted into several Glass components.
Utils.SetSolidColor = function (texture, r, g, b, a)
  if texture.SetColorTexture then
    texture:SetColorTexture(r, g, b, a)
  else
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
  end
end
