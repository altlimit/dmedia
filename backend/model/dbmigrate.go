package model

var (
	dbMigrations []string
)

func init() {
	dbMigrations = append(dbMigrations, `
		CREATE TABLE media (
			id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, 
			name TEXT NOT NULL,
			public INTEGER NOT NULL DEFAULT 0,
			checksum TEXT NOT NULL,
			ctype TEXT NOT NULL,
			path TEXT NOT NULL,
			created DATE NOT NULL,
			modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			size INTEGER NOT NULL DEFAULT 0,
			meta JSON
		);
		CREATE INDEX idx_modified on media(modified);
		CREATE UNIQUE INDEX idx_checksum on media(checksum);
		CREATE UNIQUE INDEX idx_path on media(path);
	`)
}
