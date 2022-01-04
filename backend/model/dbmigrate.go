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
			created DATETIME NOT NULL,
			modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			deleted DATETIME,
			size INTEGER NOT NULL DEFAULT 0,
			meta JSON
		);
		CREATE INDEX idx_modified on media(modified);
		CREATE UNIQUE INDEX idx_checksum on media(checksum);
	`,
		`
		CREATE TABLE sync_location (
			id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			stype TEXT NOT NULL,
			deleted DATETIME,
			config JSON
		);
		CREATE TABLE sync_media (
			id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			location_id INTEGER NOT NULL,
			media_id INTEGER NOT NULL,
			meta TEXT NOT NULL
		);
		CREATE UNIQUE INDEX idx_loc_media on sync_media(location_id,media_id);
	`,
	}
	dbMigrations = []string{
		`CREATE TABLE user (
			id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			password TEXT NOT NULL,
			admin INTEGER NOT NULL DEFAULT 0,
			active INTEGER NOT NULL DEFAULT 1,
			created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);
		CREATE UNIQUE INDEX idx_username on user(name);
		`,
	}

	dbMigrateTable = `
		CREATE TABLE migrations (version INTEGER NOT NULL);
		INSERT INTO migrations (version) VALUES (0);
	`
)
