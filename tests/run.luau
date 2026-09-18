--!nonstrict
-- Test girişi. Doğrudan `luau tests/run.luau` ile ÇALIŞMAZ:
-- kaynak modüller bağımlılıklarını Roblox servis ağacından çözüyor.
-- `scripts/test.sh` önce scripts/prepare_tests.py ile build/test/ altına
-- require yolları yeniden yazılmış bir kopya çıkarır, sonra bunu koşar.
local Framework = require("./framework")

require("./specs/Format.spec")
require("./specs/Rng.spec")
require("./specs/Loot.spec")
require("./specs/Economy.spec")
require("./specs/Heist.spec")
require("./specs/Layout.spec")
require("./specs/EventClock.spec")
require("./specs/Config.spec")

local failed = Framework.run()
if failed > 0 then
	os.exit(1)
end
