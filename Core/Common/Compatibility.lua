--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...

-- 3.3.5 Compatibility: WOW_PROJECT constants don't exist
if (not _G.WOW_PROJECT_ID) then
	_G.WOW_PROJECT_ID = 1
	_G.WOW_PROJECT_MAINLINE = 1
	_G.WOW_PROJECT_CLASSIC = 2
	_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
	_G.WOW_PROJECT_WRATH_CLASSIC = 11
	-- For 3.3.5, we'll mark it as Wrath
	local _, _, _, interface = GetBuildInfo()
	if (interface and interface >= 30000 and interface < 40000) then
		_G.WOW_PROJECT_ID = 11 -- WOW_PROJECT_WRATH_CLASSIC
	end
end

-- 3.3.5 Compatibility: CreateFromMixins doesn't exist
if (not _G.CreateFromMixins) then
	_G.CreateFromMixins = function(...)
		local mixin = {}
		for i = 1, select("#", ...) do
			local source = select(i, ...)
			if source then
				for k, v in pairs(source) do
					mixin[k] = v
				end
			end
		end
		return mixin
	end
end

-- 3.3.5 Compatibility: CopyTable might not exist
if (not _G.CopyTable) then
	local function CopyTableInternal(settings, shallow)
		local copy = {}
		for k, v in pairs(settings) do
			if type(v) == "table" and not shallow then
				copy[k] = CopyTableInternal(v, shallow)
			else
				copy[k] = v
			end
		end
		return copy
	end
	_G.CopyTable = function(settings, shallow)
		return CopyTableInternal(settings, shallow)
	end
end

-- 3.3.5 Compatibility: UnitNameUnmodified doesn't exist
if (not _G.UnitNameUnmodified) then
	_G.UnitNameUnmodified = function(unit)
		local name = UnitName(unit)
		return name
	end
end

-- Backdrop template for Lua and XML
-- Allows us to always set these templates, even in Classic.
local MixinGlobal = Addon.."BackdropTemplateMixin"
_G[MixinGlobal] = {}
if (BackdropTemplateMixin) then
	if (CreateFromMixins) then
		_G[MixinGlobal] = CreateFromMixins(BackdropTemplateMixin) -- Usable in XML
	end
	-- ns.Private may not exist yet if loaded early from .toc
	if (ns.Private) then
		ns.Private.BackdropTemplate = "BackdropTemplate" -- Usable in Lua
	end
end

-- Create an alias for the classics.
if (not _G.UnitEffectiveLevel) then
	_G.UnitEffectiveLevel = UnitLevel
end

-- Functions that would always return false when not present.
for _,global in next,{
	"IsXPUserDisabled",
	"UnitHasVehicleUI"
} do
	if (not _G[global]) then
		_G[global] = function() return false end
	end
end

-- 3.3.5 Compatibility: C_Timer doesn't exist
-- Create a simple animation-based timer implementation
if (not _G.C_Timer) then
	local timerFrame = CreateFrame("Frame")
	local timers = {}
	local timerID = 0

	timerFrame:SetScript("OnUpdate", function(self, elapsed)
		local now = GetTime()
		for id, timer in pairs(timers) do
			if (timer.nextTick and now >= timer.nextTick) then
				if (timer.callback) then
					timer.callback()
				end
				if (timer.iterations) then
					timer.iterations = timer.iterations - 1
					if (timer.iterations <= 0) then
						timers[id] = nil
					else
						timer.nextTick = now + timer.delay
					end
				elseif (timer.repeating) then
					timer.nextTick = now + timer.delay
				else
					timers[id] = nil
				end
			end
		end
		-- Hide frame if no timers
		if (not next(timers)) then
			self:Hide()
		end
	end)
	timerFrame:Hide()

	_G.C_Timer = {}

	-- C_Timer.After(seconds, callback)
	_G.C_Timer.After = function(seconds, callback)
		timerID = timerID + 1
		timers[timerID] = {
			callback = callback,
			delay = seconds,
			nextTick = GetTime() + seconds,
			repeating = false
		}
		timerFrame:Show()
	end

	-- C_Timer.NewTimer(seconds, callback) - returns a timer handle
	_G.C_Timer.NewTimer = function(seconds, callback)
		timerID = timerID + 1
		local id = timerID
		timers[id] = {
			callback = callback,
			delay = seconds,
			nextTick = GetTime() + seconds,
			repeating = false
		}
		timerFrame:Show()
		return {
			Cancel = function()
				timers[id] = nil
			end,
			IsCancelled = function()
				return timers[id] == nil
			end
		}
	end

	-- C_Timer.NewTicker(seconds, callback, iterations) - returns a ticker handle
	_G.C_Timer.NewTicker = function(seconds, callback, iterations)
		timerID = timerID + 1
		local id = timerID
		timers[id] = {
			callback = callback,
			delay = seconds,
			nextTick = GetTime() + seconds,
			repeating = (not iterations),
			iterations = iterations
		}
		timerFrame:Show()
		return {
			Cancel = function()
				timers[id] = nil
			end,
			IsCancelled = function()
				return timers[id] == nil
			end
		}
	end
end
