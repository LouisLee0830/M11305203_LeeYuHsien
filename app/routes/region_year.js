const express = require("express");
const router = express.Router();

// GET /region-year/ 
router.get("/", (req, res) => {
  const sqlRegions = `
    SELECT RegionID, RegionName
    FROM Region
    ORDER BY RegionName
  `;

  const sqlYears = `
    SELECT DISTINCT Year
    FROM InternetUserFact
    ORDER BY Year DESC
  `;

  router.connection.query(sqlRegions, (err1, regions) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    router.connection.query(sqlYears, (err2, years) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("region_year", {
        title: "Region Summary",
        regions,
        years,
      });
    });
  });
});

// GET /region-year/summary?regionId=..&year=..
router.get("/summary", (req, res) => {
  const regionId = req.query.regionId;
  const year = req.query.year;

  if (!regionId || !year) {
    return res.status(400).send("Missing regionId or year");
  }

  const sqlRegionName = `SELECT RegionName FROM Region WHERE RegionID = ?`;

  const sql = `
    SELECT
      r.RegionName,
      sr.SubRegionName,
      SUM(f.InternetUsers) AS TotalInternetUsers
    FROM InternetUserFact f
    JOIN Country c ON c.CountryID = f.CountryID
    JOIN SubRegion sr ON sr.SubRegionID = c.SubRegionID
    JOIN Region r ON r.RegionID = c.RegionID
    WHERE c.RegionID = ?
      AND f.Year = ?
    GROUP BY r.RegionName, sr.SubRegionName
    ORDER BY r.RegionName ASC, TotalInternetUsers ASC, sr.SubRegionName ASC
  `;

  router.connection.query(sqlRegionName, [regionId], (err1, rRows) => {
    if (err1) return res.status(500).send(err1.sqlMessage);

    const regionName = rRows.length ? rRows[0].RegionName : "(Unknown)";

    router.connection.query(sql, [regionId, year], (err2, rows) => {
      if (err2) return res.status(500).send(err2.sqlMessage);

      return res.render("region_year_summary", {
        regionName,
        year,
        rows,
        hasData: rows.length > 0,
      });
    });
  });
});

module.exports = router;
