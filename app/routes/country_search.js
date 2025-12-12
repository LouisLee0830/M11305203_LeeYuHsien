const express = require("express");
const router = express.Router();

// GET /country-search/ 
router.get("/", (req, res) => {
  return res.render("country_search", {
    title: "Country Search",
  });
});

// GET /country-search/results
router.get("/results", (req, res) => {
  const q = (req.query.q || "").trim();

  
  if (q.length === 0) {
    return res.render("country_search_results", {
      q,
      rows: [],
      hasData: false,
      message: "Type a keyword to search (partial match).",
    });
  }

  // Newest InternetUsers
  const sql = `
    SELECT
      c.CountryName,
      f.Year AS LatestYear,
      f.InternetUsers
    FROM Country c
    JOIN (
      SELECT CountryID, MAX(Year) AS MaxYear
      FROM InternetUserFact
      GROUP BY CountryID
    ) mx ON mx.CountryID = c.CountryID
    JOIN InternetUserFact f
      ON f.CountryID = mx.CountryID AND f.Year = mx.MaxYear
    WHERE c.CountryName LIKE CONCAT('%', ?, '%')
    ORDER BY c.CountryName ASC
    LIMIT 200
  `;

  router.connection.query(sql, [q], (err, rows) => {
    if (err) return res.status(500).send(err.sqlMessage);

    return res.render("country_search_results", {
      q,
      rows,
      hasData: rows.length > 0,
      message: rows.length === 0 ? "No matching countries." : null,
    });
  });
});

module.exports = router;
