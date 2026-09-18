--!nonstrict
-- İstemci açılışı.
local Net = require(script.Controllers.Net)
local State = require(script.Controllers.State)
local App = require(script.UI.App)

Net.init()
State.init()
App.mount()

-- Sunucu ilk profili kendisi gönderiyor; yine de yeniden bağlanma
-- durumunda mevcut durumu istiyoruz.
task.delay(1, function()
	Net.invoke("AdvanceTutorial")
end)
