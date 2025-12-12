const express = require("express");
const router = express.Router();

// GET /records/update/
router.get("/", (req, res) => {
  const sqlCountries = `SELECT CountryID, CountryName FROM Country ORDER BY CountryName`;
  const sqlYears = `SELECT DISTINCT Year FROM InternetUserFact ORDER BY Year DESC`;

  router.connection.query(sqlCountries, (err1, countries) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    router.connection.query(sqlYears, (err2, years) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("record_update", { countries, years });
    });
  });
});

// GET /records/update/load?countryId=..&year=.. 
router.get("/load", (req, res) => {
  const countryId = parseInt(req.query.countryId, 10);
  const year = parseInt(req.query.year, 10);

  if (!countryId || !year) return res.status(400).send("Missing countryId or year");

  const sql = `
    SELECT c.CountryName, f.Year, f.InternetUsers
    FROM InternetUserFact f
    JOIN Country c ON c.CountryID = f.CountryID
    WHERE f.CountryID = ? AND f.Year = ?
  `;

  router.connection.query(sql, [countryId, year], (err, rows) => {
    if (err) return res.status(500).send(err.sqlMessage);

    if (rows.length === 0) {
      return res.render("record_update_form", {
        hasData: false,
        countryId,
        year
      });
    }

    return res.render("record_update_form", {
      hasData: true,
      countryId,
      year: rows[0].Year,
      countryName: rows[0].CountryName,
      internetUsers: rows[0].InternetUsers
    });
  });
});

// POST /records/update/submit
router.post("/submit", (req, res) => {
  const countryId = parseInt(req.body.countryId, 10);
  const year = parseInt(req.body.year, 10);
  const internetUsers = req.body.internetUsers;

  if (!countryId || !year || internetUsers === undefined || internetUsers === "") {
    return res.status(400).send("Missing countryId, year, or internetUsers");
  }

  const sql = `
    UPDATE InternetUserFact
    SET InternetUsers = ?
    WHERE CountryID = ? AND Year = ?
  `;

  router.connection.query(sql, [internetUsers, countryId, year], (err, result) => {
    if (err) return res.status(500).send(err.sqlMessage);

    if (result.affectedRows === 0) {
      return res.status(404).send("Record not found (nothing updated).");
    }

    return res.render("record_update_result", {
      countryId,
      year,
      internetUsers
    });
  });
});

module.exports = router;
