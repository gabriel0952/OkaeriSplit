const jwt = require("jsonwebtoken");
const fs = require("fs");

// ====== 請修改以下資訊 ======
const TEAM_ID = "US9K7N9C57";
const KEY_ID = "428AU8U6C4";          // Apple 建立 Key 時給的 Key ID
const CLIENT_ID = "com.raycat.okaerisplit";
const P8_PATH = "./AuthKey_428AU8U6C4.p8";   // 你的 .p8 檔案路徑
// ============================

const privateKey = fs.readFileSync(P8_PATH, "utf8");

const token = jwt.sign({}, privateKey, {
  algorithm: "ES256",
  expiresIn: "180d",
  audience: "https://appleid.apple.com",
  issuer: TEAM_ID,
  subject: CLIENT_ID,
  keyid: KEY_ID,
});

console.log("\n=== Apple Client Secret (JWT) ===\n");
console.log(token);
console.log("\n=== 請將上方 JWT 貼到 Supabase 的 Secret Key 欄位 ===\n");
