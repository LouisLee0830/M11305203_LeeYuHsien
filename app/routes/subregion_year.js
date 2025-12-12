const express = require("express");
const router = express.Router();

// GET /subregion-year/
router.get("/", (req, res) => {
  const sqlSubRegions = `
    SELECT SubRegionID, SubRegionName
    FROM SubRegion
    ORDER BY SubRegionName
  `;

  const sqlYears = `
    SELECT DISTINCT Year
    FROM InternetUserFact
    ORDER BY Year DESC
  `;

  router.connection.query(sqlSubRegions, (err1, subregions) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    router.connection.query(sqlYears, (err2, years) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      // years
      return res.render("subregion_year", {
        title: "Sub-region by Year",
        subregions,
        years,
      });
    });
  });
});

// GET /subregion-year/list?subRegionId=..&year=..
router.get("/list", (req, res) => {
  const subRegionId = req.query.subRegionId;
  const year = req.query.year;

  if (!subRegionId || !year) {
    return res.status(400).send("Missing subRegionId or year");
  }

  const sql = `
    SELECT
      c.CountryName,
      f.InternetUsers
    FROM InternetUserFact f
    JOIN Country c ON c.CountryID = f.CountryID
    JOIN SubRegion sr ON sr.SubRegionID = c.SubRegionID
    WHERE c.SubRegionID = ?
      AND f.Year = ?
    ORDER BY f.InternetUsers ASC, c.CountryName ASC
  `;

  const sqlSubRegionName = `SELECT SubRegionName FROM SubRegion WHERE SubRegionID = ?`;

  router.connection.query(sqlSubRegionName, [subRegionId], (err1, srRows) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    const subRegionName = srRows.length ? srRows[0].SubRegionName : "(Unknown)";

    router.connection.query(sql, [subRegionId, year], (err2, rows) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("subregion_year_list", {
        subRegionName,
        year,
        rows,
        hasData: rows.length > 0,
      });
    });
  });
});


module.exports = router;
