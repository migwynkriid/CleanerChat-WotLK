local _, ns = ...

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

-- Create an alias for the classics.
if (not _G.UnitEffectiveLevel) then
	_G.UnitEffectiveLevel = UnitLevel
end

-- 3.3.5 Compatibility: GetAddOnEnableState doesn't exist
-- (added in a later expansion). On 3.3.5 we default every addon to "enabled" (2).
if (not _G.GetAddOnEnableState) then
	_G.GetAddOnEnableState = function() return 2 end
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
-- Create a timer implementation that:
-- 1. Provides global _G.C_Timer for libraries like AceTimer-3.0 that require it
-- 2. Uses pcall to protect against buggy callbacks from other addons (e.g. MRT)
-- 3. Also stores in ns.Timer for internal use
if (not _G.C_Timer) then
	local timerFrame = CreateFrame("Frame")
	local timers = {}
	local timerID = 0

	timerFrame:SetScript("OnUpdate", function(self, elapsed)
		local now = GetTime()

		-- Two-phase update to avoid "invalid key to 'next'".
		-- A timer callback frequently schedules a NEW timer (rescheduling itself
		-- or arming another), which inserts into `timers`. In Lua 5.1, adding a
		-- new key to a table *during* pairs() iteration is undefined behavior and
		-- throws "invalid key to 'next'". Removing existing keys is safe, so we
		-- first walk the table to find due timers and update their scheduling
		-- state (removals only), then fire the callbacks AFTER the loop closes --
		-- at which point callbacks may freely add new timers.
		local due
		for id, timer in pairs(timers) do
			if (timer.nextTick and now >= timer.nextTick) then
				due = due or {}
				due[#due + 1] = timer

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

		-- Fire callbacks after iteration has finished. Safe for callbacks to add
		-- new timers now. pcall protects against buggy callbacks from other addons
		-- (like MRT's nil self) so they don't spam the error log or break the loop.
		if (due) then
			for i = 1, #due do
				local callback = due[i].callback
				if (callback) then
					pcall(callback)
				end
			end
		end

		-- Hide frame if no timers
		if (not next(timers)) then
			self:Hide()
		end
	end)
	timerFrame:Hide()

	-- Create global C_Timer (required by AceTimer-3.0 and other libraries)
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

	-- Also expose as ns.Timer for internal convenience
	ns.Timer = _G.C_Timer
end
