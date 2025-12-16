# 🧰 Chore Scripts – Kho tiện ích nhỏ cho dự án ADT

**Repo:** [KaneLabb/chore-scripts](https://github.com/KaneLabb/chore-scripts)

Chào mừng bạn đến với **Chore Scripts**, nơi tập hợp những đoạn mã nhỏ, script tiện ích cho dự án ADT (Air Data), bao gồm các công cụ để tạo service, sao chép database và cấu hình môi trường phát triển.

> Những script này giúp tự động hóa các tác vụ lặp lại trong quá trình phát triển.

---

## 📦 Nội dung repo

Repo này chứa các script được viết bằng Bash và cấu hình Docker:

- **Bash** – Tạo service ADT, sao chép database, quản lý môi trường
- **Docker & Compose** – Cấu hình môi trường test nhanh (Postgres, Redis, MongoDB)

Một số ví dụ:

| Script | Mô tả ngắn |
|--------|-----------|
| `adt-g-service.sh` | Tạo entity, repository, service, types, controller, DTO cho một entity mới |
| `adt-u-service.sh` | Cập nhật repository, service, types cho tất cả entities hiện có |
| `clone-db.sh` | Sao chép database từ môi trường develop về local |
| `docker-compose.yml` | Cấu hình môi trường với Redis, MongoDB, Postgres |

---

## 🔧 Cách sử dụng

1. Clone repo:

```bash
git clone https://github.com/KaneLabb/chore-scripts.git
cd chore-scripts
chmod +x  clone-db.sh

run clone-db.sh