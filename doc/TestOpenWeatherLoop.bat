@echo off

rem 2020-11-16  20:00:00
set ts=1605592801

set cnt=1

:loop
set cmd="https://api.openweathermap.org/data/2.5/onecall/timemachine?appid=cf43d8434ebb694a27f7e5b4b9af1dbf&lat=52.00&lon=10.9&dt=%ts%&units=imperial"

echo %cmd%

curl -sS -o D:\RaspBerry\Sprinklers\TestDaten\OpenWeather%ts%_%cnt%.json %cmd%

timeout /T 3600

set /a ts=%ts%+3600
set /a cnt=%cnt%+1

goto loop



