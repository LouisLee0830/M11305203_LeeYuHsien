const config = {
  db: {
    host: "172.17.0.2",      // 目前從宿主機連 Docker 裡的 MySQL
    port: 3306,
    user: "root",
    password: "123456",     // 你啟動 internet-users-db 時設定的 root 密碼
    database: "InternetUsers",
    connectTimeout: 60000,
  },
};

module.exports = config;