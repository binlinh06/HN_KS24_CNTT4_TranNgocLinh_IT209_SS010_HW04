# Bài 4: Thiết lập Custom Network và Named Volume bằng Docker CLI

## 1. Mục tiêu

- Tạo Custom Bridge Network để các Container giao tiếp qua DNS nội bộ.
- Tạo Named Volume để lưu trữ dữ liệu PostgreSQL bền vững.
- Triển khai PostgreSQL và Backend bằng Docker CLI.
- Kiểm chứng dữ liệu sau khi xóa và tạo lại Database Container.

## 2. Kiến trúc triển khai

- Network: `app-net`
- Named Volume: `db-data`
- Database Container: `db-server`
- Backend Container: `app-container`
- PostgreSQL Image: `postgres:15-alpine`
- Backend Image: `hw-backend:v1`

Backend và Database cùng tham gia Network `app-net`. Backend sử dụng hostname `db-server` và cổng PostgreSQL `5432` để xác định địa chỉ Database.

Named Volume `db-data` được mount vào `/var/lib/postgresql/data` để lưu trữ dữ liệu PostgreSQL bên ngoài vòng đời của Container.

## 3. Triển khai

Chạy các lệnh:

```bash
chmod +x commands.sh
./commands.sh
```

Kiểm tra Network và Volume:

```bash
docker network ls | grep app-net
docker volume ls | grep db-data
docker network inspect app-net
```

Kiểm tra các Container:

```bash
docker ps
```

## 4. Kiểm tra DNS nội bộ

```bash
docker exec -it app-container ping -c 2 db-server
```

Kết quả mong đợi là hostname `db-server` được phân giải thành IP nội bộ và nhận được phản hồi từ Database Container.

Nếu image Backend không có `ping`, có thể kiểm tra DNS bằng Node.js:

```bash
docker exec app-container node -e "require('dns').lookup('db-server',(err,address)=>{if(err){console.error(err);process.exit(1)}console.log(address)})"
```

## 5. Kiểm tra Data Persistence

Tạo bảng và chèn dữ liệu:

```bash
docker exec db-server psql -U appuser -d appdb -c "CREATE TABLE IF NOT EXISTS persistence_test (id SERIAL PRIMARY KEY, message TEXT);"

docker exec db-server psql -U appuser -d appdb -c "INSERT INTO persistence_test (message) VALUES ('Docker Volume survives container removal');"
```

Kiểm tra dữ liệu:

```bash
docker exec db-server psql -U appuser -d appdb -c "SELECT * FROM persistence_test;"
```

Xóa Container Database:

```bash
docker rm -f db-server
```

Tạo lại Container với Volume cũ:

```bash
docker run -d --name db-server --network app-net --network-alias db-server -e POSTGRES_USER=appuser -e POSTGRES_PASSWORD=LabPassword123 -e POSTGRES_DB=appdb -v db-data:/var/lib/postgresql/data postgres:15-alpine
```

Đợi Database sẵn sàng rồi truy vấn lại:

```bash
until docker exec db-server pg_isready -U appuser -d appdb; do sleep 2; done

docker exec db-server psql -U appuser -d appdb -c "SELECT * FROM persistence_test;"
```

Nếu bản ghi vẫn còn sau khi Container được tạo lại, thử nghiệm Data Persistence thành công.

## 6. Kết luận

Custom Bridge Network cho phép Backend và PostgreSQL giao tiếp qua DNS nội bộ của Docker mà không cần sử dụng IP cố định. Named Volume tách dữ liệu khỏi vòng đời Container, nhờ đó dữ liệu vẫn được giữ lại khi Container Database bị xóa và tạo mới, miễn là Volume không bị xóa và được mount đúng cách.

Lưu ý: Backend trong bài lab hiện sử dụng image của bài 2 và chưa thực hiện truy vấn PostgreSQL thực tế. Bài này kiểm tra khả năng kết nối mạng/DNS và cơ chế lưu trữ bền vững.
