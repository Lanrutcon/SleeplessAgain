local Addon = CreateFrame("FRAME", "SleeplessAgain");


local mainFrame, hungerBar, thirstBar, temperatureBar, energyBar;



------------------------------------------
--Utils
------------------------------------------

local function round(num, idp)
  local mult = 10^(idp or 0);
  return math.floor(num * mult + 0.5) / mult;
end

local function isBetween(x, inf, sup)
	return x > inf and x < sup;
end

local function isPlayerEating()
	if(UnitBuff("player", "Food")) then
		return true;
	end
	return false;
end

local function isPlayerDrinking()
	if(UnitBuff("player", "Drink")) then
		return true;
	end
	return false;
end

local function isCampfireNear()
	local x, y = GetPlayerMapPosition("player");
	x, y = round(x*1000), round(y*1000);
	if (isBetween(x,temperatureBar.campX-3, temperatureBar.campX+3) and
		isBetween(y,temperatureBar.campY-3, temperatureBar.campY+3)) then
			return true;
	end
	return false;
end



--is player with bad condition

local function isBadStatus()
	return hungerBar.bad or thirstBar.bad or temperatureBar.bad;
end

local function isTired()
	return energyBar.bad;
end




local flashFrame = CreateFrame("FRAME");

local function cancelFlash()
	if(not flashFrame:GetScript("OnUpdate")) then
		return;
	end
	local total, alpha = 0, UIParent:GetAlpha();
	flashFrame:SetScript("OnUpdate", function(self, elapsed)
		total = total + elapsed;
		if(total > 0.02) then
			alpha = alpha + total;
			total = 0;
			UIParent:SetAlpha(alpha)
			if(alpha >= 1) then
				self:SetScript("OnUpdate", nil);
			end
		end
	end);
end


local function flashUIParent()
	if(not flashFrame:GetScript("OnUpdate")) then
		local total, alpha, fadingIn = 0, 1, false;
		flashFrame:SetScript("OnUpdate", function(self, elapsed)
			total = total + elapsed;
			if(total > 0.02) then
				if(alpha >= 1) then
					fadingIn = false;
				elseif(alpha < 0) then
					fadingIn = true;
				end
				if(fadingIn) then
					alpha = alpha + total;
				else
					alpha = alpha - total;
				end
				UIParent:SetAlpha(alpha);

				total = 0;
				if(not isBadStatus()) then
					cancelFlash();
				end
			end
		end);
	end
end


--Black frame - when player's energy is low
local blackFrame = CreateFrame("FRAME", nil, WorldFrame);
blackFrame:SetFrameStrata("DIALOG");
blackFrame:SetFrameLevel(7);
blackFrame:SetAllPoints();
blackFrame.texture = blackFrame:CreateTexture();
blackFrame.texture:SetTexture(0,0,0,1);
blackFrame.texture:SetAllPoints();

blackFrame:Hide();


local function cancelBlackFlash()
	if(not blackFrame:GetScript("OnUpdate")) then
		return;
	end
	local total, alpha = 0, blackFrame:GetAlpha();
	UIFrameFadeOut(blackFrame, alpha, alpha, 0);
	blackFrame:SetScript("OnUpdate", function(self, elapsed)
		total = total + elapsed;
		if(total > alpha) then
			blackFrame:Hide();
			blackFrame:SetScript("OnUpdate", nil);
		end
	end);
end


local function fadeToBlack()
	if(not blackFrame:GetScript("OnUpdate")) then
		local total, alpha, fadingIn = 0, 0, true;
		blackFrame:SetScript("OnUpdate", function(self, elapsed)
			total = total + elapsed;
			if(total > 0.02) then
				if(alpha >= 1) then
					fadingIn = false;
				elseif(alpha < 0) then
					fadingIn = true;
				end
				if(fadingIn) then
					alpha = alpha + total;
				else
					alpha = alpha - total;
				end
				blackFrame:SetAlpha(alpha);

				total = 0;
				if(not isTired()) then
					cancelBlackFlash();
				end
			end
		end);
		blackFrame:Show();
	end
end




local frameTrap = CreateFrame("FRAME");
--a frame that triggers when the player casts campfire
--it checks if the player is near the campfire.
local function createTrigger()
	
	local throttle, totalElapsed, x, y = 0, 0;
	frameTrap:SetScript("OnUpdate", function(self, elapsed)
		throttle = throttle + elapsed;
		if(throttle > 0.1) then
			totalElapsed = totalElapsed + throttle;
			throttle = 0;
			if(not isCampfireNear()) then
				temperatureBar.warmingUp = false;
			else
				temperatureBar.warmingUp = true;
			end
			if(totalElapsed > 300) then
				temperatureBar.warmingUp = false;
				self:SetScript("OnUpdate", nil);
			end
		end
	end);

end


------------------------------------------



local function createBar(name, text, texture, point, xOfs, yOfs)

	local frame = CreateFrame("FRAME", name, mainFrame);
	frame:SetSize(512*0.5,64*0.5);
	frame:SetPoint(point, xOfs, yOfs);
	
	frame.bg = frame:CreateTexture();
	frame.bg:SetTexture("Interface\\AddOns\\SleeplessAgain\\Textures\\"..texture..".blp");
	frame.bg:SetAllPoints();

	
	frame.pointer = frame:CreateTexture(nil, "OVERLAY");
	frame.pointer:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark");
	frame.pointer:SetBlendMode("ADD");
	frame.pointer:SetSize(32, 50);
	frame.pointer:SetPoint("CENTER");
	
	frame.text = frame:CreateFontString(nil, "OVERLAY");
	frame.text:SetFont("Interface\\AddOns\\Rising\\Futura-Condensed-Normal.TTF", 16, "OUTLINE");
	frame.text:SetTextColor(0.2, 0.6, 0.2, 1);
	frame.text:SetText(text);
	frame.text:SetPoint("TOPLEFT", 37, 15);
	
	frame.number = frame:CreateFontString(nil, "OVERLAY");
	frame.number:SetFont("Interface\\AddOns\\Rising\\Futura-Condensed-Normal.TTF", 9, "OUTLINE");
	frame.number:SetTextColor(0.5, 0.5, 0.5, 1);
	frame.number:SetText(100);
	frame.number:SetPoint("CENTER", 76, 0);

	
	return frame;

end



--------------------------------------
--Energy Bar section

-- 63 = full
-- -86 = empty

local function updateEnergyBar()
	energyBar.value = energyBar.value - 1/36;		-- at this rate it takes 1hour to go from full to empty
	if(energyBar.value > 100) then
		energyBar.value = 100;	
	elseif(energyBar.value < 0) then
		energyBar.value = 0;	
	end
	
	
	-- energy 	- point
	-- 100	   	- 63
	-- 50		- (63+86)/2 = 16
	-- 0		- -86
	energyBar.pointer:SetPoint("CENTER", (energyBar.value)/100*63+(100-energyBar.value)/100*-86, 0);
	energyBar.number:SetText(math.floor(energyBar.value+0.5));
	
	SleeplessAgainSV[UnitName("player")]["Energy"] = energyBar.value;
	
	if(energyBar.value < 10) then
		energyBar.bad = true;
	else
		energyBar.bad = false;
	end

end



local sleepFrame;
local function setUpSleepFrame()
	sleepFrame = CreateFrame("FRAME", "SASleepFrame", WorldFrame);
	sleepFrame:SetFrameStrata("TOOLTIP");
	sleepFrame:SetFrameLevel(5);
	sleepFrame:SetAllPoints();
	sleepFrame.texture = sleepFrame:CreateTexture();
	sleepFrame.texture:SetTexture(0,0,0,1);
	sleepFrame.texture:SetAllPoints();

	sleepFrame:Hide();
end



--called when a player chooses the option to rest in an innkeeper

local function restoreEnergy()
	
	--sleep
	if(not sleepFrame) then
		setUpSleepFrame();
	end
	--UIFrameFlash(frame, fadeInTime, fadeOutTime, flashDuration, showWhenDone, flashInHoldTime, flashOutHoldTime)
	UIFrameFlash(sleepFrame, 0.5, 0.5, 10, false, 9, 0);
	PlaySoundFile("Interface\\AddOns\\SleeplessAgain\\RestSound.mp3");
	
	local total = 0;
	sleepFrame:SetScript("OnUpdate", function(self, elapsed)
		total = total + elapsed;
		if(total > 5) then
			energyBar.value = 100;
			updateEnergyBar();
			self:SetScript("OnUpdate", nil);
		end
	end);
	
end

local function addRestOption()
	local titleButton = _G["GossipTitleButton" .. GossipFrame.buttonIndex];
	_G[titleButton:GetName().."GossipIcon"]:SetTexture("Interface\\CharacterFrame\\UI-StateIcon");
	_G[titleButton:GetName().."GossipIcon"]:SetTexCoord(0, 0.5, 0, 0.421875);
	titleButton:SetText("I want to rest.");
	
	titleButton:SetScript("OnClick", function(self, button)
		restoreEnergy();
	end);
	
	GossipFrame.buttonIndex = GossipFrame.buttonIndex + 1;
	
	titleButton:Show();
end


local function isTargetInnkeeper()
	local unitID = tonumber((UnitGUID("target")):sub(-12, -9), 16);
	if(SAInnkeeperList[unitID]) then
		return true;
	end
	return false;
end


--------------------------------------
--Hunger Bar section


local function updateHungerBar()

	if(hungerBar.eating) then
		hungerBar.value = hungerBar.value + 5;
	else
		hungerBar.value = hungerBar.value - 1/18;	-- at this rate it takes 1/2hour to go from full to empty
	end
	
	if(hungerBar.value > 100) then
		hungerBar.value = 100;	
	elseif(hungerBar.value < 0) then
		hungerBar.value = 0;	
	end
	
	
	hungerBar.pointer:SetPoint("CENTER", (hungerBar.value)/100*63+(100-hungerBar.value)/100*-86, 0);
	hungerBar.number:SetText(math.floor(hungerBar.value+0.5));
	
	SleeplessAgainSV[UnitName("player")]["Hunger"] = hungerBar.value;


	if(hungerBar.value < 10) then
		hungerBar.bad = true;
	else
		hungerBar.bad = false;
	end

end



--------------------------------------
--Hunger Bar section


local function updateThirstBar()

	if(thirstBar.drinking) then
		thirstBar.value = thirstBar.value + 5;
	else
		thirstBar.value = thirstBar.value - 3/36;	-- at this rate it takes 1/3hour to go from full to empty
	end
	
	if(thirstBar.value > 100) then
		thirstBar.value = 100;	
	elseif(thirstBar.value < 0) then
		thirstBar.value = 0;
	end
	
	
	if(thirstBar.value < 10) then
		thirstBar.bad = true;
	else
		thirstBar.bad = false;
	end
	
	
	thirstBar.pointer:SetPoint("CENTER", (thirstBar.value)/100*63+(100-thirstBar.value)/100*-86, 0);
	thirstBar.number:SetText(math.floor(thirstBar.value+0.5));
	
	SleeplessAgainSV[UnitName("player")]["Thirst"] = thirstBar.value;

end




--------------------------------------
--Temperature Bar section




local function updateTemperateBar()

	if(IsIndoors()) then
		local tempDiff = 36.5-temperatureBar.value;
		temperatureBar.value = temperatureBar.value + tempDiff/10;
	elseif(temperatureBar.warmingUp) then
		temperatureBar.value = temperatureBar.value + 1/10;
	else
		local zoneTemperature, tempDiff = SAMapList[GetZoneText()], 0;
		if(zoneTemperature) then
			tempDiff = zoneTemperature - 18;
		end
		
		---------
		--BodyTemp -	AmbientTemp -	tempDiff -	shouldChange
		--36.5			32				32-18=14	14>6 && 36.5-32=4.5<7  	-> yes
		--38			32				14			14>6 && 38-32=6<7 		-> yes
		--40			32				14			14>6 && 40-32=8>7		-> no
		--
		--36.5			28				28-18=10	10>6 && 36.5-28=8.5<7	-> no
		--
		--36.5			10				10-18=-8	8>6	 &&	36.5-10=26.5>25	->yes
		--34			10				-8			8>6  && 34-10=24>24		->no
		--
		--
		--36.5			0				0-18=-18	18>6 &&	36.5-0=36.5>25	->yes
		--33			0				-18			18>6 && 33-0=33>25		->yes
		
		
		if(tempDiff > 6 and math.abs(temperatureBar.value-zoneTemperature) < 7) then
			temperatureBar.value = temperatureBar.value + tempDiff/2500;
		elseif(tempDiff < -6 and math.abs(temperatureBar.value-zoneTemperature) > 25) then
			temperatureBar.value = temperatureBar.value + tempDiff/2500;
		end
	end
	
	if(temperatureBar.value > 41) then
		temperatureBar.value = 41;	
	elseif(temperatureBar.value < 32) then
		temperatureBar.value = 32;	
	end
	
	if(temperatureBar.value > 39 or temperatureBar.value < 34) then
		temperatureBar.bad = true;
	else
		temperatureBar.bad = false;
	end
	-- temp 	- point
	-- 41	   	- 63
	-- 36.5		- (63+86)/2 = 16
	-- 32		- -86
	temperatureBar.pointer:SetPoint("CENTER", 13+((temperatureBar.value-32)/9*63)+(42-temperatureBar.value)/9*-86, 0);
	temperatureBar.number:SetText(round(temperatureBar.value, 1));
	
	SleeplessAgainSV[UnitName("player")]["Temperature"] = temperatureBar.value;

end


------------------------------------------



local function setUpBars()

	--mainFrame
	mainFrame = CreateFrame("FRAME", "SA");
	mainFrame:SetSize(300*0.7, 250);
	mainFrame:SetPoint("CENTER");
	
	mainFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
                       edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
                       tile = true, tileSize = 18, edgeSize = 18, 
                       insets = { left = 4, right = 4, top = 4, bottom = 4 }});
	mainFrame:SetBackdropColor(0,0,0,1);

	--energyBar
	energyBar = createBar("SAEnergyBar", "Energy", "bar_red-green", "TOP", 0 , -25-10);
	energyBar.value = 100;

	--hungerBar
	hungerBar = createBar("SAHungerBar", "Hunger", "bar_red-green", "TOP", 0, -90);
	hungerBar.value = 100;
	
	
	--thirstBar
	thirstBar = createBar("SAThirstBar", "Thirst", "bar_red-green", "TOP", 0, -90-55);
	thirstBar.value = 100;
	
	
	--temperatureBar
	temperatureBar = createBar("SATemperatureBar", "Temperature", "bar_blue-red", "TOP", 0, -90-55-55);
	temperatureBar.value = 36.5;


	
	
	
	mainFrame:SetScript("OnMouseDown", function(self, button)
		if(button == "LeftButton" and IsShiftKeyDown() and IsAltKeyDown()) then
			mainFrame:SetMovable(true);
			mainFrame:StartMoving();		
		end
	end);
	
	mainFrame:SetScript("OnMouseUp", function(self, button)
		if(button == "LeftButton" and IsShiftKeyDown() and IsAltKeyDown()) then
			mainFrame:SetMovable(false);
			mainFrame:StopMovingOrSizing();
			SleeplessAgainSV[UnitName("player")]["Position"] = { mainFrame:GetPoint() };
		end
	end);

end






local function loadSavedVariables()

	if(not SleeplessAgainSV) then
		SleeplessAgainSV = {};
		SleeplessAgainSV[UnitName("player")] = {};
	elseif(SleeplessAgainSV[UnitName("player")]) then
		hungerBar.value = SleeplessAgainSV[UnitName("player")]["Hunger"];
		energyBar.value = SleeplessAgainSV[UnitName("player")]["Energy"];
		thirstBar.value = SleeplessAgainSV[UnitName("player")]["Thirst"];
		temperatureBar.value = SleeplessAgainSV[UnitName("player")]["Temperature"];
		
		mainFrame:SetPoint(unpack(SleeplessAgainSV[UnitName("player")]["Position"]));
	else
		SleeplessAgainSV[UnitName("player")] = {};
	end

end


local total = 0;
local function onUpdate(self, elapsed)
	total = total + elapsed;
	if(total > 1) then
		total = 0;
		updateEnergyBar();
		updateHungerBar();
		updateThirstBar();
		updateTemperateBar();
		if(isBadStatus()) then
			--UIFrameFlash(frame, fadeInTime, fadeOutTime, flashDuration, showWhenDone, flashInHoldTime, flashOutHoldTime)
			--UIFrameFlash(UIParent, 0.5, 0.5, 20, true, 2, 2);
			flashUIParent();
		end	
		if(isTired()) then
			fadeToBlack();
		end
	end
end

Addon:SetScript("OnUpdate", onUpdate);



Addon:SetScript("OnEvent", function(self, event, ...)

	if(event == "GOSSIP_SHOW" and isTargetInnkeeper()) then
		addRestOption();
	elseif(event == "UNIT_AURA" and ... == "player") then
		if(isPlayerEating()) then
			hungerBar.eating = true;
		else
			hungerBar.eating = false;
		end
		if(isPlayerDrinking()) then
			thirstBar.drinking = true;
		else
			thirstBar.drinking = false;
		end
	elseif(event == "UNIT_SPELLCAST_SUCCEEDED") then
		local unit, spellName = ...;
		if(... == "player" and spellName == "Cooking Fire") then
			temperatureBar.campX, temperatureBar.campY = GetPlayerMapPosition("player");
			temperatureBar.campX, temperatureBar.campY = round(temperatureBar.campX*1000), round(temperatureBar.campY*1000);
			temperatureBar.warmingUp = true;
			createTrigger();
		end
		
	elseif(event == "PLAYER_ENTERING_WORLD") then
    	setUpBars();
    	loadSavedVariables();
    	Addon:UnregisterEvent("PLAYER_ENTERING_WORLD");
	end

end);

Addon:RegisterEvent("PLAYER_ENTERING_WORLD");
Addon:RegisterEvent("GOSSIP_SHOW");
Addon:RegisterEvent("UNIT_AURA");
Addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");