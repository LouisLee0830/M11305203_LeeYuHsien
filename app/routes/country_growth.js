const express = require("express");
const router = express.Router();

// GET /country-growth/ -> page
router.get("/", (req, res) => {
  const sql = `SELECT CountryID, CountryName FROM Country ORDER BY CountryName`;

  router.connection.query(sql, (err, countries) => {
    if (err) return res.status(500).send(err.sqlMessage);
    return res.render("country_growth", { countries });
  });
});

// GET /country-growth/table?countryId=..
router.get("/table", (req, res) => {
  const countryId = parseInt(req.query.countryId, 10);
  if (!countryId) return res.status(400).send("Missing countryId");

  const sqlCountry = `SELECT CountryName FROM Country WHERE CountryID = ?`;

  const sql = `
    SELECT
      cur.Year,
      cur.InternetUsers AS CurrentUsers,
      prev.InternetUsers AS PreviousUsers,
      (cur.InternetUsers - prev.InternetUsers) AS Growth
    FROM InternetUserFact cur
    LEFT JOIN InternetUserFact prev
      ON prev.CountryID = cur.CountryID
     AND prev.Year = cur.Year - 1
    WHERE cur.CountryID = ?
    ORDER BY cur.Year ASC
  `;

  router.connection.query(sqlCountry, [countryId], (err1, cRows) => {
    if (err1) return res.status(500).send(err1.sqlMessage);
    const countryName = cRows[0].CountryName;

    router.connection.query(sql, [countryId], (err2, rows) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("country_growth_table", {
        countryName,
        rows,
        hasData: rows.length > 0
      });
    });
  });
});

module.exports = router;
