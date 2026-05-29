-- Match End Config - Cấu hình điều kiện kết thúc trận đấu
-- Module này chứa các cấu hình cho hệ thống kết thúc trận đấu

local MatchEndConfig = {}

-- ========== CẤU HÌNH CHÍNH ==========

-- Điều kiện thắng dựa trên KILLS
MatchEndConfig.KILLS_TO_WIN = 10  -- Số kills cần để thắng (đặt = 0 để tắt)

-- Điều kiện thắng dựa trên SÁT THƯƠNG BASE
MatchEndConfig.BASE_DAMAGE_TO_WIN = 1000  -- Tổng sát thương lên base để thắng (đặt = 0 để tắt)

-- Thời gian tối đa của trận đấu (giây)
MatchEndConfig.MAX_MATCH_DURATION = 300  -- 5 phút

-- Thời gian delay trước khi kết thúc trận (giây)
MatchEndConfig.END_MATCH_DELAY = 3

-- ========== CẤU HÌNH HIỂN THỊ ==========

-- Có hiển thị GUI thống kê không?
MatchEndConfig.SHOW_STATS_GUI = true

-- Vị trí GUI (UDim2)
MatchEndConfig.GUI_POSITION = UDim2.new(0.5, -150, 0, 10)

-- Kích thước GUI (UDim2)
MatchEndConfig.GUI_SIZE = UDim2.new(0, 300, 0, 120)

-- ========== CẤU HÌNH ĐIỂM RANKING ==========

-- Điểm thưởng khi thắng
MatchEndConfig.WIN_POINTS = 25

-- Điểm trừ khi thua
MatchEndConfig.LOSE_POINTS = -20

-- Điểm khi hòa
MatchEndConfig.DRAW_POINTS = 5

-- ========== HƯỚNG DẪN SỬ DỤNG ==========
--[[

CÁCH CHỈNH SỬA CẤU HÌNH:

1. Thay đổi số kills để thắng:
   MatchEndConfig.KILLS_TO_WIN = 15  -- Thay đổi từ 10 thành 15 kills

2. Tắt điều kiện kills:
   MatchEndConfig.KILLS_TO_WIN = 0  -- Đặt = 0 để không dùng kills

3. Thay đổi thời gian trận đấu:
   MatchEndConfig.MAX_MATCH_DURATION = 600  -- 10 phút

4. Thay đổi sát thương base để thắng:
   MatchEndConfig.BASE_DAMAGE_TO_WIN = 2000  -- Cần 2000 damage

CÁC ĐIỀU KIỆN KẾT THÚC TRẬN ĐẤU:

1. KILLS: Team nào đạt số kills định trước sẽ thắng
2. BASE_DAMAGE: Team nào gây đủ sát thương lên base đối phương sẽ thắng
3. TIME: Khi hết thời gian, team có nhiều kills hơn sẽ thắng
   - Nếu kills bằng nhau, team có nhiều damage hơn sẽ thắng
   - Nếu cả kills và damage bằng nhau, trận đấu sẽ HÒA

LƯU Ý:
- Có thể bật/tắt từng điều kiện bằng cách đặt giá trị = 0
- Nếu tất cả điều kiện đều tắt, trận đấu sẽ chỉ kết thúc khi hết thời gian

]]--

return MatchEndConfig