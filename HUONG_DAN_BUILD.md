# Hướng dẫn Build ZTech iOS bằng GitHub Actions (Trên Windows)

Toàn bộ mã nguồn ứng dụng iOS (**Objective-C / UIKit + Theos**) và cấu hình tự động biên dịch đã được tạo sẵn trong thư mục `ZTech_iOS`.

---

## 1. Cấu trúc dự án đã tạo
* [Makefile](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/Makefile) & [control](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/control): Cấu hình biên dịch Theos cho iOS 14.0+ (`arm64` / `arm64e`).
* [entitlements.xml](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/entitlements.xml) & [postinst](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/layout/DEBIAN/postinst): Cấp quyền `platform-application` cho máy Jailbreak/TrollStore và tự động chạy `uicache` để hiện icon ngoài màn hình chính ngay sau khi cài `.deb`.
* [ZTechRootViewController.m](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/Sources/ZTechRootViewController.m): Giao diện Dark-Gold giống hệt ảnh mẫu:
  * Khung `IDENTIFIER` hiển thị UUID, đời máy (`iPhone 15 Pro (iPhone16,1) · iOS 17.1.2`), % pin, nhà mạng, Wi-Fi, tỉnh/thành phố, số danh bạ.
  * 4 công tắc tuỳ chỉnh (`Khoá đời máy`, `Respring after Change`, `Fake màn hình`, `Khớp chip`).
  * Nút `Change device · Đổi máy` và `Đồng bộ vị trí theo IP`.
  * Khung `CHECK` kèm nút `Copy report · Sao chép`.
* [ZTechDeviceDatabase.m](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/Sources/ZTechDeviceDatabase.m): Cơ sở dữ liệu thông số phần cứng thật của các đời iPhone 12 -> 15 Pro Max (khớp chuẩn mã `hw.machine`, độ phân giải màn hình, dòng Chip + RAM), tự động ghi 7 file `.plist` cấu hình, đồng bộ vị trí theo IP mạng hiện tại và hỗ trợ `sbreload` (Respring).
* [build-ios.yml](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/.github/workflows/build-ios.yml): Workflow chạy trên máy ảo `macos-latest` của GitHub Actions.

---

## 2. Cách đẩy lên GitHub để lấy file `.deb` / `.tipa`
1. Lên [github.com/new](https://github.com/new) tạo một Repository mới (nên chọn **Public** để được miễn phí không giới hạn số phút chạy máy ảo macOS).
2. Chạy file [PUSH_LEN_GITHUB.bat](file:///m:/11111111-%20tool%20quang%20lam/ZTech_iOS/PUSH_LEN_GITHUB.bat) trong thư mục `ZTech_iOS`, dán link repo GitHub của bạn vào và nhấn Enter.
3. Mở tab **Actions** trên repo GitHub của bạn, đợi khoảng **2 phút** để tiến trình `Build ZTech iOS` chạy xong (tích xanh).
4. Kéo xuống mục **Artifacts** ở cuối trang Actions, tải file **`ZTech-iOS-Packages.zip`** về. Bên trong có sẵn đủ 4 định dạng:
   * `ZTech_Rootless_arm64.deb`: Cài qua **Sileo / Zebra / Filza** cho máy Jailbreak **Rootless** (Dopamine, palera1n iOS 15 – 16+).
   * `ZTech_Rootful_arm.deb`: Cài cho máy Jailbreak **Rootful** (Unc0ver, Checkra1n, palera1n rootful).
   * `ZTech_TrollStore.tipa`: Mở qua **TrollStore** để cài trực tiếp.
   * `ZTech_App.ipa`: Bộ cài IPA tiêu chuẩn.
