const express = require("express");
const router = express.Router();

// GET /records/delete
router.get("/", (req, res) => {
  const sqlCountries = `SELECT CountryID, CountryName FROM Country ORDER BY CountryName`;
  const sqlYears = `SELECT DISTINCT Year FROM InternetUserFact ORDER BY Year DESC`;

  router.connection.query(sqlCountries, (err1, countries) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    router.connection.query(sqlYears, (err2, years) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("record_delete", { countries, years });
    });
  });
});

// GET /records/delete/preview?countryId=..&y1=..&y2=..
router.get("/preview", (req, res) => {
  const countryId = parseInt(req.query.countryId, 10);
  const y1 = parseInt(req.query.y1, 10);
  const y2 = parseInt(req.query.y2, 10);

  if (!countryId || !y1 || !y2) return res.status(400).send("Missing countryId/y1/y2");

  const startYear = Math.min(y1, y2);
  const endYear = Math.max(y1, y2);

  const sqlCountry = `SELECT CountryName FROM Country WHERE CountryID = ?`;
  const sqlCount = `
    SELECT COUNT(*) AS Cnt
    FROM InternetUserFact
    WHERE CountryID = ?
      AND Year BETWEEN ? AND ?
  `;

  router.connection.query(sqlCountry, [countryId], (err1, cRows) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    const countryName = cRows.length ? cRows[0].CountryName : "(Unknown)";

    router.connection.query(sqlCount, [countryId, startYear, endYear], (err2, rows2) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      const cnt = rows2[0].Cnt;

      return res.render("record_delete_preview", {
        countryId,
        countryName,
        startYear,
        endYear,
        cnt,
        hasData: cnt > 0
      });
    });
  });
});

// POST /records/delete/confirm 
router.post("/confirm", (req, res) => {
  const countryId = parseInt(req.body.countryId, 10);
  const y1 = parseInt(req.body.startYear, 10);
  const y2 = parseInt(req.body.endYear, 10);

  if (!countryId || !y1 || !y2) return res.status(400).send("Missing countryId/startYear/endYear");

  const startYear = Math.min(y1, y2);
  const endYear = Math.max(y1, y2);

  const sqlCountry = `SELECT CountryName FROM Country WHERE CountryID = ?`;
  const sqlDelete = `
    DELETE FROM InternetUserFact
    WHERE CountryID = ?
      AND Year BETWEEN ? AND ?
  `;

  router.connection.query(sqlCountry, [countryId], (err1, cRows) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    const countryName = cRows.length ? cRows[0].CountryName : "(Unknown)";

    router.connection.query(sqlDelete, [countryId, startYear, endYear], (err2, result) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("record_delete_result", {
        countryId,
        countryName,
        startYear,
        endYear,
        deletedRows: result.affectedRows
      });
    });
  });
});

module.exports = router;
