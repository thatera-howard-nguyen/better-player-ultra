# Yêu cầu chức năng (SPEC rút gọn)

## 1) Khu vực chạm

-   Mỗi bên **trái** và **phải** chiếm **40%** chiều rộng màn hình.\
-   **20% giữa** là vùng "trung lập" (không kích hoạt double-tap seek,
    vẫn giữ logic hiện tại của single-tap/controls).

## 2) Hành vi trước khi double-tap

-   **Không thay đổi** logic hiện có (single-tap, show/hide controls,
    v.v.).\
-   Chỉ khi phát hiện **double-tap** trong vùng trái/phải mới kích hoạt
    overlay + logic seek.

## 3) Trong khi double-tap (tích lũy + animation)

-   **Double-tap** ở:
    -   **Bên trái** ⇒ seek **−10s** (rewind).
    -   **Bên phải** ⇒ seek **+10s** (forward).
-   Hiển thị **icon mũi tên** (\<\< hoặc \>\>) + **nhãn số giây** (ví dụ
    "10", "20", "30"...), kèm **fade** nền trong vùng 40% tương ứng.
-   **Tích lũy nhiều lần**: trong **khoảng thời gian tích lũy** (ví dụ
    **\~300--500ms "grace window"** kể từ lần double-tap gần nhất), mọi
    lần tap thêm **trong cùng vùng** đều được coi là **một lần cộng
    dồn** (+/−10s mỗi lần), **chưa seek ngay**.
-   Hết **grace window** ⇒ **thực hiện seek một lần** theo **tổng tích
    lũy** (ví dụ người dùng tap 3 lần phải trong cửa sổ → +30s, sau đó
    mới seek +30s).
-   **Animation**:
    -   Vùng 40% được **dim/fade** (opacity \~0.4), **icon** + **nhãn
        tổng giây** **fade-in** nhanh (150--200ms), giữ trong thời gian
        tích lũy, và **fade-out** khi kết thúc.
    -   **Ripple/bounce nhẹ** mỗi lần tap thêm để phản hồi thị giác
        (không bắt buộc nhưng nên có).
-   **Haptic feedback** (nếu khả dụng): "light impact" cho mỗi lần tap
    tích lũy, "medium" khi thực hiện seek.

## 4) Sau khi double-tap

-   **Thực hiện seek** đúng tổng số giây đã tích lũy.
-   **Ẩn overlay/animation** (fade-out nhanh 150--200ms).
-   Trả UI về trạng thái trước đó (không tự ý pause/play, không bật
    controls nếu trước đó đang ẩn).

## 5) Quy tắc thời gian & giới hạn

-   **Grace window tích lũy**: 300--500ms (khuyến nghị **400ms**) ---
    reset mỗi lần tap thêm.
-   **Giới hạn tích lũy tối đa**: tuỳ app (khuyến nghị **±90s** hoặc
    **±120s** để tránh nhảy quá xa**)**.
-   **Debounce**: không nhận thêm tap khi overlay đang **fade-out**
    (trong \~150--200ms), trừ khi bắt đầu một chu kỳ tích lũy mới.

## 6) Tương tác khác & ưu tiên gesture

-   **Single-tap** ở vùng trung lập vẫn **show/hide controls** như hiện
    tại.
-   **Double-tap** **ưu tiên** so với single-tap trong vùng 40% hai bên
    (tránh trigger nhầm controls).
-   **Press-and-hold**: **không triển khai** (theo yêu cầu hiện tại). Có
    thể cân nhắc sau (fast-scrub).
-   Ngăn chặn **xung đột** với gesture hệ thống (ví dụ back swipe ở mép
    trái iOS) bằng việc bắt gesture **từ rìa vào \~24--32px** hoặc dùng
    HitTestBehavior phù hợp.

## 7) Trạng thái phát & biên video

-   Nếu **seek vượt biên** (đầu/cuối), clamp về **0** hoặc **duration**.
-   Không đổi trạng thái **play/pause** hiện tại (chỉ nhảy thời gian).
-   Khi **buffering**: chấp nhận queue seek; nếu player hỗ trợ, gộp vào
    một seek cuối.

## 8) Khả năng hiển thị & layout

-   **Portrait/Landscape** đều giữ quy tắc 40% -- 20% -- 40%.
-   **Icon** + **nhãn số giây** căn **gần mép tap** (trái/phải), nằm
    **bên trong vùng 40%** tương ứng; tránh đè lên notch/home indicator.
-   **Text nhãn**: hiển thị **tổng tích lũy** ("10s", "20s", "30s"...).
    Có thể kèm chữ "Forward/Backward" nhỏ.

## 9) Truy cập (Accessibility)

-   Hỗ trợ **TalkBack/VoiceOver**: khi double-tap thành công, đọc ngắn
    gọn "Forward 10 seconds" / "Rewind 10 seconds".
-   **Tap target** đủ lớn và tương phản overlay đạt **WCAG AA**.

## 10) Telemetry (tuỳ chọn nhưng nên có)

-   Log event: `video_double_tap_accumulate` (side, taps, total_seconds,
    elapsed_ms),\
    và `video_seek_applied` (from_ms, to_ms, delta_ms, buffered_state).

------------------------------------------------------------------------

### Gợi ý kỹ thuật (rất ngắn)

-   Dùng **2 GestureDetector** phủ trái/phải (40% mỗi bên),
    `HitTestBehavior.translucent`.
-   State: `accumMs`, `lastTapAt`, `side`, `timer` (reset sau mỗi tap).
-   Mỗi tap:
    -   Nếu cùng **side** và **now - lastTapAt \< window**,
        `accumMs += 10000`.
    -   Ngược lại, **apply seek** nếu `accumMs != 0` rồi **khởi tạo
        phiên mới** cho side mới.
-   Hết window ⇒ `player.seekBy(sign*accumMs)` → `accumMs=0` →
    **fade-out overlay**.
