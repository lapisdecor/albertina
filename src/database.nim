import db_connector/db_sqlite, std/options, std/strutils

var db: DbConn

proc initDatabase*() =
  let dbPath = "albertina.db"
  db = open(dbPath, "", "", "")
  db.exec(sql"""
    CREATE TABLE IF NOT EXISTS definitions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      term TEXT UNIQUE NOT NULL,
      definition TEXT NOT NULL
    )
  """)

proc closeDatabase*() =
  db.close()

proc getDefinition*(term: string): Option[string] =
  let row = db.getRow(sql"SELECT definition FROM definitions WHERE term = ?", term)
  if row[0].len > 0 or (row[0] == "" and db.getValue(sql"SELECT count(*) FROM definitions WHERE term = ?", term) == "1"):
    # getRow returns an array of strings. If not found, it returns empty strings,
    # but we need to be careful if definition itself is empty.
    return some(row[0])
  
  # A more robust way:
  let count = db.getValue(sql"SELECT count(*) FROM definitions WHERE term = ?", term).parseInt()
  if count > 0:
    return some(db.getValue(sql"SELECT definition FROM definitions WHERE term = ?", term))
  else:
    return none(string)

proc searchTerms*(query: string): seq[string] =
  var results: seq[string] = @[]
  let likeQuery = "%" & query & "%"
  for row in db.fastRows(sql"SELECT term FROM definitions WHERE term LIKE ? ORDER BY term COLLATE NOCASE ASC", likeQuery):
    results.add(row[0])
  return results

proc getAllTerms*(): seq[string] =
  var results: seq[string] = @[]
  for row in db.fastRows(sql"SELECT term FROM definitions ORDER BY term COLLATE NOCASE ASC"):
    results.add(row[0])
  return results

proc saveDefinition*(term: string, definition: string) =
  # Insert or replace (update)
  db.exec(sql"""
    INSERT INTO definitions (term, definition) 
    VALUES (?, ?) 
    ON CONFLICT(term) DO UPDATE SET definition=excluded.definition
  """, term, definition)

proc deleteTerm*(term: string) =
  db.exec(sql"DELETE FROM definitions WHERE term = ?", term)
