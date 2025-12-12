const express = require("express");
const path = require("path");
const db = require("mysql2");
const app = express();

app.set("views", path.join(__dirname, "views"));
app.set("view engine", "hjs");
app.use(express.urlencoded({ extended: true }));
app.use(express.static("public"));

const configs = require("./config");
const connection = db.createConnection(configs.db);

connection.connect((err) => {
  if (err) {
    console.log("Error connecting to database: ", err);
    process.exit(1);
  } else {
    console.log("Connected to database");
  }
});

// Home
app.get("/", (req, res) => {
  if (req.get("HX-Request")) {
    return res.render("index", { title: "Internet Users Project" });
  }

  return res.render("layout", {
    title: "Internet Users Project",
    partials: { navbar: "navbar" },
  });
});

// IMPORTANT: any non-HTMX request should be wrapped by layout,
// and let layout load the real content via hx-get="{{where}}"
app.get(/.*/, (req, res, next) => {
  if (req.get("HX-Request")) return next();

  return res.render("layout", {
    title: "Internet Users Project",
    partials: { navbar: "navbar" },
    where: req.url,
  });
});

app.listen(80, function () {
  console.log("Web server listening on port 80!");
});

// routes
const country = require("./routes/country");
country.connection = connection;
app.use("/country", country);

const subregionYear = require("./routes/subregion_year");
subregionYear.connection = connection;
app.use("/subregion-year", subregionYear);
