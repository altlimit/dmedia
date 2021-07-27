const List<String> dbMigrations = [
  """
  CREATE TABLE media (
			id INTEGER NOT NULL PRIMARY KEY, 
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
    CREATE INDEX idx_deleted on media(deleted);
		CREATE UNIQUE INDEX idx_checksum on media(checksum);
  """
];
