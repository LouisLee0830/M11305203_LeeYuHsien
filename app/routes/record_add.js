const express = require("express");
const router = express.Router();

// GET /records/add/ -> 顯示表單
router.get("/", (req, res) => {
  const sql = `SELECT CountryID, CountryName FROM Country ORDER BY CountryName`;
  router.connection.query(sql, (err, countries) => {
    if (err) return res.status(500).send(err.sqlMessage);
    return res.render("record_add", { countries });
  });
});

// POST /records/add/submit -> 新增下一年度資料
router.post("/submit", (req, res) => {
  const countryId = parseInt(req.body.countryId, 10);
  const internetUsers = req.body.internetUsers;

  if (!countryId || internetUsers === undefined || internetUsers === "") {
    return res.status(400).send("Missing countryId or internetUsers");
  }

  // 最大年度
  const sqlMaxYear = `
    SELECT MAX(Year) AS MaxYear
    FROM InternetUserFact
    WHERE CountryID = ?
  `;

  router.connection.query(sqlMaxYear, [countryId], (err1, rows1) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    const maxYear = rows1[0].MaxYear;
    if (maxYear === null) {
      return res.status(400).send("This country has no existing records, cannot determine next year.");
    }

    const nextYear = maxYear + 1;

    const sqlExists = `
      SELECT 1
      FROM InternetUserFact
      WHERE CountryID = ? AND Year = ?
      LIMIT 1
    `;

    router.connection.query(sqlExists, [countryId, nextYear], (err2, rows2) => {
      if (err2) return res.status(500).send(err2.sqlMessage);
      if (rows2.length > 0) {
        return res.status(409).send(`Record already exists for next year (${nextYear}).`);
      }

      const sqlInsert = `
        INSERT INTO InternetUserFact (CountryID, Year, InternetUsers)
        VALUES (?, ?, ?)
      `;

      router.connection.query(sqlInsert, [countryId, nextYear, internetUsers], (err3) => {
        if (err3) return res.status(500).send(err3.sqlMessage);

        return res.render("record_add_result", {
          countryId,
          nextYear,
          internetUsers,
        });
      });
    });
  });
});

module.exports = router;
