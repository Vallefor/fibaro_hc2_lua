--[[
%% properties
183 value
%% globals
--]]
fibaro:debug('start scene');

thisScene=87; --ID этой сцены

rowVar='eye_row_bedroom'; --Переменная куда записывается непрерывная активность сенсора движения
manualVar='bedroom_manual';
rowToLock=1; -- Количество срабатываний сенсора в комнате, чтоб сработал коридор лок (еслис енсоров несколько, то число должно быть больше)
deviceId= { 183 }; --Сенсоры движения

luxId={ {310,7} }; --Сенсор освещенности и его порог
outerDeviceId=104; -- Сенсор движения в коридоре
outerDeviceSecs=-10; --Разница между коридорным и внутренним сенсором, для блокировки выключения

dayVal=1; --Дневное значение включения
nightVal=20; --Ночное значение включения

sleepTimeDay={};
sleepTimeNight={};
sleepTimeDay[183]=60; --Задержка отключения днем (в секундах), на определенное устройство
sleepTimeNight[183]=120; --Задержка отключения ночью (в секундах), на определенное устройство

dimmersDay={ 86 };  --Включаем днем
dimmersNight={ 152 }; --Включаем ночью

shouldBeOff={ 84, 86, 152 }; --Какие устройства должны быть выключены, чтоб скрипт включения сработал




-- Дальше идет код одинаковый для всех:
local startSource = fibaro:getSourceTrigger();

if(fibaro:getGlobalValue(manualVar)=='1')
  then
  	fibaro:abort();
  end

--fibaro:abort();

function getLastMove(deviceId)
	lastBreach=tonumber(fibaro:getGlobalValue("eye_"..deviceId));
	if(lastBreach=='100') then lastBreach=os.time(); end;
	return tonumber(lastBreach);
end

function isCorridorLast(deviceId,outerDeviceId,outerDeviceSecs)
  	fibaro:debug("check: start!");
    lastBreach=tonumber(fibaro:getGlobalValue("eye_"..outerDeviceId));
  	if(lastBreach=='100') then lastBreach=os.time(); end;
  	check=0;
	for i = 1, #deviceId do 
		check=lastBreach-getLastMove(deviceId[i]);
    	fibaro:debug("check:"..check);
    	if(check>outerDeviceSecs)
      	then
      		fibaro:debug("check: true!");
      		return true;
      	end
	end
  	fibaro:debug("check: false!");
  	return false;
end

function rowVarOff()
	fibaro:setGlobal(rowVar,'0');
  	fibaro:debug('rowVar off');
end

luxPass=false;
for i = 1, #luxId do 
  	if(tonumber(fibaro:getValue(luxId[i][1],"value"))<luxId[i][2])
    then
    	luxPass=true;
    end
end

local motion=0;
local triggerMotion=0;
sleepTime=0;
for i = 1, #deviceId do 
    if(startSource['type']=='property')
    	then
      		if(tonumber(startSource['deviceID'])==deviceId[i])
        	then
        		triggerMotion=tonumber(fibaro:getValue(deviceId[i], "value"));
        	end
      	end
	motion=motion+tonumber(fibaro:getValue(deviceId[i], "value"));
  	if(fibaro:getGlobalValue("night")=='1')
    then
    	if(sleepTimeNight[deviceId[i]]>sleepTime)
      	then
    		sleepTime=sleepTimeNight[deviceId[i]]*1000;
      	end
    else
    	if(sleepTimeDay[deviceId[i]]>sleepTime)
      	then
    		sleepTime=sleepTimeDay[deviceId[i]]*1000;
      	end
    end
end
  
if(triggerMotion==0 and motion>0) --Если много сенсоров движения и 1 сработал на выключение но другие активны, то ничего не делаем
	then
    	fibaro:abort();
	end


inRoomMove=getLastMove(deviceId[1]);
outRoomMove=getLastMove(outerDeviceId);
--fibaro:debug('inRoomMove:'..inRoomMove..' outRoomMove:'..outRoomMove..'  inRoomMove-outRoomMove:'..(inRoomMove-outRoomMove));


if(fibaro:getGlobalValue("night")=='1')
    then
  		setVal=nightVal;
		dimmers = dimmersNight;
    else
  		setVal=dayVal;
    	dimmers = dimmersDay;
    end
  
local summLight=0;

for i = 1, #dimmers do 
	summLight=summLight+tonumber(fibaro:getValue(dimmers[i], "value"));
end

if((luxPass==false and summLight==0) or fibaro:getGlobalValue("someoneSleep")=='1' or fibaro:getGlobalValue("someoneAtHome")=='0')
  then
    fibaro:setGlobal(rowVar,0);
  	fibaro:abort();
  end

  
  
if(tonumber(fibaro:getGlobalValue("night")) < 1 and dayVal=='off')
	then
		fibaro:abort();
	end

if(tonumber(fibaro:getGlobalValue("night")) == 1 and nightVal=='off')
	then
		fibaro:abort();
	end


if(motion>0)
then
  	fibaro:setGlobal(rowVar,tonumber(fibaro:getGlobalValue(rowVar))+1);
  	needToOn=true;
  	for i = 1, #shouldBeOff do 
    	if(tonumber(fibaro:getValue(shouldBeOff[i], "value"))>0)
      	then
      		needToOn=false;
    	end
 	end
  	if(needToOn==true --[[and tonumber(fibaro:getGlobalValue("night")) == 0--]])
    then
    
        if(outRoomMove>inRoomMove and tonumber(fibaro:getValue(outerDeviceId, "value"))<1)
  			then
  				fibaro:call(191, 'sendPush', 'Возможно свет в '..rowVar..' сейчас включать не надо.');
			end
    
      if(tonumber(fibaro:getGlobalValue("night")) < 1)
      then
          for i = 1, #dimmers do 
              if(dayVal~='off')
              then
                  fibaro:call(dimmers[i], "setValue", dayVal);
              end
          end
      else
          for i = 1, #dimmers do 
              if(nightVal~='off')
              then
                  fibaro:call(dimmers[i], "setValue", nightVal);
              end
          end
      end
    end
    fibaro:killScenes(thisScene);
end
    
if(motion==0)
then
  	if fibaro:countScenes() > 1 then fibaro:abort() end
    fibaro:sleep(sleepTime);
    if(tonumber(fibaro:getGlobalValue(rowVar))>rowToLock)
    then
      fibaro:debug("Corridor lock: "..fibaro:getGlobalValue(rowVar));
      while(true)
      do
        if(isCorridorLast(deviceId,outerDeviceId,outerDeviceSecs))
          then
            fibaro:debug("corridor exit! Should off!");
            break;
          end
        fibaro:sleep(30*1000)
      end
    fibaro:debug("exit cycle!");
    else
      fibaro:debug(rowVar.." less than "..rowToLock..' ('..fibaro:getGlobalValue(rowVar)..')');
    end
  
  fibaro:debug("exit cycle 2!");

	for i = 1, #shouldBeOff do 
    	if(setVal~='off')
        then
      		fibaro:debug("exit cycle 3! = "..tostring(dimmers[i]).." - "..tostring(i));
      		if(tostring(dimmers[i])~='nil')
        	then
          		fibaro:call(dimmers[i], "turnOff");
        	end
      fibaro:debug("exit cycle 3.2!");
        end
    	fibaro:debug("exit cycle 3.5!");
	end
  	
  	fibaro:debug("exit cycle 4!");
  	fibaro:debug('start rowVar off');
  	setTimeout(rowVarOff,10*1000);
end
