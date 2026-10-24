# Đặc Tả Kỹ Thuật Module MAC PE (Multiply-Accumulate Processing Element)

Tài liệu này mô tả chi tiết kiến trúc phần cứng, giao tiếp tín hiệu, phân tích số học và quy trình kiểm thử module **Processing Element (PE)** thực hiện phép tính **Multiply-Accumulate (MAC)** viết bằng SystemVerilog, được thiết kế cho hệ thống tăng tốc phần cứng CNN trên SoC / FPGA / ASIC.

---

## 1. Tổng Quan Kiến Trúc (Architecture Overview)

Module `mac_pe` là khối xử lý cơ sở (Processing Element) thường được ghép nối thành chuỗi pipeline hoặc mảng Systolic Array 2D để thực hiện phép nhân ma trận hoặc tích chập trong mạng nơ-ron học sâu (CNN).

### Chức năng chính:
- Nhận dữ liệu đầu vào `data_in` (8-bit signed) và trọng số `weight_in` (8-bit signed).
- Thực hiện phép nhân số nguyên có dấu 2's complement: $P = \text{data\_in} \times \text{weight\_in}$ (kết quả 16-bit signed).
- Mở rộng dấu (sign-extension) lên 20-bit và cộng dồn vào thanh ghi tích lũy `acc_out`:
  $$\text{acc\_out}[t] = \text{acc\_out}[t-1] + (\text{data\_in} \times \text{weight\_in})$$
- Tích hợp tín hiệu xóa bộ tích lũy đồng bộ `clr_acc` và tín hiệu cho phép hoạt động `en`.
- Reset bất đồng bộ tích cực mức thấp `rst_n`.

```
                +-------------------------------------------------------+
                |                        mac_pe                         |
                |                                                       |
 data_in [7:0]  |--------+                                              |
 (signed)       |        |                                              |
                |        v                                              |
 weight_in [7:0]|---> [ x ] Signed Multiplier (16-bit signed)           |
 (signed)       |        |                                              |
                |        v                                              |
                |     [ Sign Extension ] (16 -> 20 bits)                |
                |        |                                              |
                |        +-----------------> [ + ] Adder (20-bit signed)|
                |                             ^                         |
                |                             |                         |
 clr_acc ------>|---------\                   |                         |
                |          v                  |                         |
 en ----------->|---> [ Control & MUX ]       |                         |
                |          |                  |                         |
 clk ---------->|          v                  |                         |
 rst_n -------->|---> [ Accumulator Register ]<-------------------------+
                |             |                                         |
                |             +---------------------------------------->| acc_out [19:0]
                +-------------------------------------------------------+
```

---

## 2. Giao Tiếp Tín Hiệu & Tham Số (I/O Ports & Parameters)

### 2.1. Tham số cấu hình (Parameters)

| Tên tham số | Kiểu dữ liệu | Giá trị mặc định | Mô tả |
| :--- | :--- | :--- | :--- |
| `DATA_WIDTH` | `int` | `8` | Độ rộng bit của dữ liệu kích hoạt đầu vào (`data_in`) |
| `WEIGHT_WIDTH` | `int` | `8` | Độ rộng bit của trọng số (`weight_in`) |
| `ACC_WIDTH` | `int` | `20` | Độ rộng bit của thanh ghi tích lũy (`acc_out`) |

### 2.2. Danh sách cổng (Port List)

| Tín hiệu | Hướng | Độ rộng (bit) | Kiểu | Mô tả |
| :--- | :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | logic | Xung nhịp hệ thống (sườn dương) |
| `rst_n` | Input | 1 | logic | Reset bất đồng bộ tích cực mức thấp (Active-low async reset) |
| `en` | Input | 1 | logic | Tín hiệu cho phép hoạt động. Khi `en = 0`, bộ tích lũy giữ nguyên giá trị |
| `clr_acc` | Input | 1 | logic | Tín hiệu xóa thanh ghi tích lũy về 0 đồng bộ theo sườn dương `clk` (khi `en = 1`) |
| `data_in` | Input | `DATA_WIDTH` (8) | logic signed | Dữ liệu đầu vào dạng bù 2 có dấu (phạm vi: $[-128, 127]$) |
| `weight_in`| Input | `WEIGHT_WIDTH` (8)| logic signed | Trọng số đầu vào dạng bù 2 có dấu (phạm vi: $[-128, 127]$) |
| `acc_out` | Output| `ACC_WIDTH` (20) | logic signed | Kết quả tích lũy dạng bù 2 có dấu (phạm vi: $[-524288, 524287]$) |

---

## 3. Phân Tích Số Học & Cơ Chế Chống Tràn (Arithmetic & Overflow Analysis)

Trong mạng CNN, các lớp tích chập (Convolutional Layers) thường sử dụng kernel kích thước $3 \times 3 = 9$ phần tử hoặc $5 \times 5 = 25$ phần tử:

1. **Phép nhân 8-bit có dấu**:
   - Giá trị nhỏ nhất (âm nhất): $-128$
   - Giá trị lớn nhất (dương nhất): $+127$
   - Tích có độ lớn cực đại: $(-128) \times (-128) = +16384 = 2^{14}$
   - Tích âm cực đại: $(-128) \times (+127) = -16256$

2. **Dải động bộ tích lũy 20-bit có dấu (Signed Accumulator Dynamic Range)**:
   - Dải giá trị: $[-2^{19}, 2^{19} - 1] = [-524288, +524287]$
   - Số chu kỳ tối đa có thể cộng dồn giá trị cực đại liên tiếp mà không bị tràn số:
     $$N_{\text{max}} = \left\lfloor \frac{524287}{16384} \right\rfloor = 32 \text{ lần}$$

Do $N_{\text{max}} = 32 > 25$ (kích thước kernel $5 \times 5$), độ rộng 20-bit đảm bảo an toàn tuyệt đối, không xảy ra hiện tượng tràn số trong quá trình tích chập thông thường mà không cần mạch bão hòa (saturation logic) phức tạp.

---

## 4. Bảng Chân Trị Điều Khiển (Operation Truth Table)

| `rst_n` | `clk` | `en` | `clr_acc` | Hoạt động của `acc_out` |
| :---: | :---: | :---: | :---: | :--- |
| `0` | X | X | X | `acc_out <= 0` (Reset bất đồng bộ) |
| `1` | $\uparrow$ | `0` | X | `acc_out <= acc_out` (Giữ nguyên trạng thái) |
| `1` | $\uparrow$ | `1` | `1` | `acc_out <= 0` (Xóa tích lũy đồng bộ) |
| `1` | $\uparrow$ | `1` | `0` | `acc_out <= acc_out + (data_in * weight_in)` (MAC) |

---

## 5. Cấu Trúc Thư Mục Dự Án (Directory Structure)

```
CNN/
├── .gitignore          # Bỏ qua các file tạm sinh ra khi mô phỏng (*.vvp, *.vcd, *.log)
├── GEMINI.md           # Tài liệu đặc tả kỹ thuật kiến trúc phần cứng (file này)
├── rtl/
│   └── mac_pe.sv       # Mã nguồn SystemVerilog cho Processing Element
├── tb/
│   └── tb_mac_pe.sv    # Self-checking Testbench toàn diện
└── sim/
    └── Makefile        # Tự động hóa biên dịch và mô phỏng với iverilog & gtkwave
```

---

## 6. Hướng Dẫn Biên Dịch & Mô Phỏng (Build & Simulation Guide)

### 6.1. Yêu cầu công cụ
- **Icarus Verilog** (`iverilog` phiên bản 10.0+ hỗ trợ cờ `-g2012`)
- **VVP** (`vvp` runtime engine)
- **GTKWave** (`gtkwave` để quan sát giản đồ sóng tín hiệu)

Cài đặt trên Ubuntu/Debian (nếu chưa có):
```bash
sudo apt-get update
sudo apt-get install -y iverilog gtkwave
```

### 6.2. Các lệnh thực thi với Makefile
Chuyển vào thư mục `sim/`:
```bash
cd sim
```

- **Biên dịch và chạy mô phỏng tự động (Mặc định)**:
  ```bash
  make all
  ```
- **Chỉ biên dịch RTL & Testbench**:
  ```bash
  make compile
  ```
- **Chạy file nhị phân mô phỏng**:
  ```bash
  make sim
  ```
- **Mở giản đồ sóng bằng GTKWave**:
  ```bash
  make wave
  ```
- **Xóa các file tạm (`.vvp`, `.vcd`, `.log`)**:
  ```bash
  make clean
  ```

---

## 7. Kịch Bản Kiểm Thử trong Testbench (`tb_mac_pe.sv`)

Testbench tự động đối chiếu kết quả (Self-checking) bao gồm 28 test cases:
1. **Asynchronous Reset Verification**: Đảm bảo `acc_out` bằng 0 ngay khi `rst_n = 0`.
2. **Basic MAC Operations**: Chuỗi phép tính tích lũy tuần tự với các số dương và âm.
3. **Corner Cases**:
   - $127 \times 127 = 16129$
   - $(-128) \times 127 = -16256$
   - $(-128) \times (-128) = 16384$
4. **Accumulation Depth & Overflow Resistance**: Cộng dồn 16 lần liên tiếp giá trị cực đại để kiểm tra dải động 20-bit.
5. **Enable Control Check**: Khi `en = 0`, giá trị tích lũy được bảo lưu không đổi.
6. **Synchronous Clear Check**: Khi `clr_acc = 1` và `en = 1`, `acc_out` được đưa về 0 và sẵn sàng cho chuỗi tích lũy mới.
