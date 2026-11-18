# FPGA Digital Scale using HX711 and UART

## 1. Giới thiệu

Đây là project xây dựng hệ thống cân điện tử sử dụng FPGA **Tang Nano 9K (Gowin GW1NR-9)** kết hợp với module chuyển đổi ADC HX711 và Load Cell.

FPGA thực hiện đọc dữ liệu từ HX711, xử lý và tính toán khối lượng, sau đó truyền kết quả qua giao tiếp UART để hiển thị hoặc xử lý trên thiết bị bên ngoài.

### Mục tiêu của project

- Đọc dữ liệu ADC 24-bit từ HX711 bằng giao tiếp Serial.
- Lấy trung bình nhiều mẫu để giảm dao động của dữ liệu cân.
- Thực hiện chức năng Tare (đưa giá trị cân về 0).
- Tính toán khối lượng theo hệ số hiệu chuẩn.
- Chuyển đổi dữ liệu nhị phân sang BCD.
- Truyền kết quả cân qua UART với baud rate 115200.

## 2. Phần cứng sử dụng

| Thành phần | Chức năng |
|---|---|
| Tang Nano 9K (GW1NR-9) | FPGA xử lý toàn bộ dữ liệu |
| HX711 | Module ADC 24-bit dành cho Load Cell |
| Load Cell | Cảm biến đo khối lượng |
| Push Button | Kích hoạt chức năng Tare |
| UART | Truyền dữ liệu cân đến thiết bị bên ngoài |

## 3. Sơ đồ hoạt động tổng quan

```text
       Load Cell
           |
           v
         HX711
           |
           | DOUT / SCK
           v
  +----------------------+
  |    Tang Nano 9K      |
  |                      |
  |    PLL 27 -> 50 MHz  |
  |           |          |
  |           v          |
  |    HX711 Controller  |
  |           |          |
  |           v          |
  |      Sample Mean     |
  |           |          |
  |           v          |
  |    Tare & Weight     |
  |     Calculation     |
  |           |          |
  |           v          |
  |      Bin To BCD      |
  |           |          |
  |           v          |
  |      UART TX         |
  +----------------------+
           |
           | UART TX
           v
    External Device
```

## 4. Nguyên lý hoạt động

Quá trình xử lý dữ liệu được thực hiện theo các bước:

**Bước 1: Tạo xung clock hệ thống**

- Clock đầu vào từ board Tang Nano 9K là 27 MHz.
- Module PLL50M tạo clock hệ thống 50 MHz cho các module xử lý.

**Bước 2: Đọc dữ liệu từ HX711**

- Module `hx711_controller` điều khiển tín hiệu SCK và đọc dữ liệu DOUT.
- Dữ liệu thu được có độ rộng 24-bit.
- Tần số SCK được thiết lập ở mức 500 kHz.

**Bước 3: Lọc trung bình dữ liệu**

- Module `Sample_Mean` thực hiện lấy trung bình 5 mẫu dữ liệu.
- Giá trị trung bình được sử dụng cho bước tính toán tiếp theo.

**Bước 4: Tare và tính toán khối lượng**

- Module `Tare_Weight_Cal` lưu giá trị ban đầu làm giá trị tare.
- Người dùng có thể nhấn nút Tare để cập nhật giá trị cân bằng mới.
- Giá trị khối lượng được tính từ độ chênh lệch giữa dữ liệu hiện tại và giá trị tare, kết hợp với hệ số hiệu chuẩn.

**Bước 5: Chuyển đổi Binary sang BCD**

- Module `Bin_To_BCD` sử dụng thuật toán Double Dabble.
- Dữ liệu khối lượng dạng nhị phân được chuyển thành BCD 32-bit để chuẩn bị truyền UART.

**Bước 6: Truyền dữ liệu UART**

- Module `uart_tx_byte` thực hiện truyền từng byte dữ liệu.
- Baud rate được thiết lập ở mức 115200.
- Dữ liệu được gửi theo định dạng:

```text
W: 00001250\r\n
```

Trong đó:
- `W:` là ký hiệu dữ liệu cân nặng.
- `00001250` là giá trị khối lượng được biểu diễn bằng 8 chữ số thập phân.
- `\r\n` là ký tự kết thúc dòng.

## 5. Cấu trúc source code

| File | Module | Chức năng |
|---|---|---|
| `top_hx711_weight_uart.v` | `top_hx711_weight_uart` | Module top, kết nối và điều khiển toàn bộ hệ thống |
| `PLL50M.v` | `PLL50M` | Tạo clock hệ thống 50 MHz từ clock 27 MHz |
| `hx711_controller.v` | `hx711_controller` | Điều khiển HX711 và đọc dữ liệu 24-bit |
| `Sample_Mean.v` | `Sample_Mean` | Tính trung bình 5 mẫu dữ liệu |
| `Tare_Weight_Cal.v` | `Tare_Weight_Cal` | Tare và tính toán khối lượng |
| `Bin_To_BCD.v` | `Bin_To_BCD` | Chuyển đổi dữ liệu Binary sang BCD |
| `key_filter.v` | `key_filter` | Lọc nhiễu nút nhấn và tạo xung Tare |
| `uart_tx_byte.v` | `uart_tx_byte` | Truyền dữ liệu UART từng byte |

## 6. Thông số cấu hình

| Thông số | Giá trị |
|---|---|
| FPGA | Gowin GW1NR-9 |
| Clock đầu vào | 27 MHz |
| Clock hệ thống | 50 MHz |
| HX711 SCK | 500 kHz |
| Số mẫu lấy trung bình | 5 |
| UART Baud rate | 115200 |
| Calibration Factor mặc định | 440 |

Lưu ý: `CALIBRATION_FACTOR` có thể được điều chỉnh để phù hợp với Load Cell và quá trình hiệu chuẩn thực tế.

## 7. Hướng dẫn sử dụng project

1. Clone repository về máy:

```bash
git clone https://github.com/PhamHuynhThaiDuong/scale_hx711_lcd_uart.git
```

2. Mở project bằng Gowin EDA.

3. Kiểm tra các file Verilog đã được thêm vào project.

4. Chọn module `top_hx711_weight_uart` làm Top Module.

5. Kiểm tra cấu hình chân FPGA trong file constraint tương ứng.

6. Thực hiện Synthesis, Place & Route và tạo file bitstream.

7. Nạp chương trình xuống board Tang Nano 9K.

8. Kết nối UART với thiết bị nhận và cấu hình:
   - Baud rate: 115200
   - Data bits: 8
   - Parity: None
   - Stop bits: 1

## 8. Trạng thái phát triển

Các chức năng được triển khai trong source code hiện tại:

- [x] Tạo clock hệ thống bằng PLL.
- [x] Đọc dữ liệu từ HX711.
- [x] Lấy trung bình 5 mẫu.
- [x] Tare và tính toán khối lượng.
- [x] Chuyển đổi Binary sang BCD.
- [x] Lọc nhiễu nút nhấn Tare.
- [x] Truyền dữ liệu cân qua UART.

## 9. Tác giả

**Pham Huynh Thai Duong**

Project: FPGA Digital Scale using HX711 and UART

Repository: https://github.com/PhamHuynhThaiDuong/scale_hx711_lcd_uart
