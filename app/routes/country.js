const express = require("express");
const router = express.Router();

router.get("/", (req, res) => {
  const sql = `SELECT CountryID, CountryName FROM Country ORDER BY CountryName`;

  router.connection.query(sql, (err, countries) => {
    if (err) return res.status(500).send(err.sqlMessage);

    return res.render("country", {
      title: "Country Timeline",
      countries,
    });
  });
});

router.get("/timeline", (req, res) => {
  const countryId = req.query.countryId;
  if (!countryId) return res.status(400).send("Missing countryId");

  const sqlCountry = `SELECT CountryName FROM Country WHERE CountryID = ?`;
  const sqlTimeline = `
    SELECT Year, InternetUsers
    FROM InternetUserFact
    WHERE CountryID = ?
    ORDER BY Year DESC
  `;

  router.connection.query(sqlCountry, [countryId], (err1, rows1) => {
    if (err1) return res.status(500).send(err1.sqlMessage);
    if (rows1.length === 0) return res.status(404).send("Country not found");

    const countryName = rows1[0].CountryName;

    router.connection.query(sqlTimeline, [countryId], (err2, rows2) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("country_timeline", {
        countryName,
        timeline: rows2,
        hasData: rows2.length > 0,
      });
    });
  });
});

module.exports = router;
