package model

var (
	mediaMigrations = []string{
		`
		CREATE TABLE media (
			id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, 
			name TEXT NOT NULL,
			public INTEGER NOT NULL DEFAULT 0,
			checksum TEXT NOT NULL,
			ctype TEXT NOT NULL,
			created DATE NOT NULL,
			modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			size INTEGER NOT NULL DEFAULT 0,
			meta JSON
		);
		CREATE INDEX idx_modified on media(modified);
		CREATE UNIQUE INDEX idx_checksum on media(checksum);
	`,
	}
	dbMigrations = []string{
		`CREATE TABLE user (
			id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			password TEXT NOT NULL,
			admin INTEGER NOT NULL DEFAULT 0,
			active INTEGER NOT NULL DEFAULT 1,
			created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
		)
		CREATE INDEX idx_username on user(name);
		`,
	}

	dbMigrateTable = `
		CREATE TABLE migrations (version INTEGER NOT NULL);
		INSERT INTO migrations (version) VALUES (0);
	`
)
