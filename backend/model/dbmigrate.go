package model

var (
	dbMigrations []string
)

func init() {
	dbMigrations = append(dbMigrations, `
		create table media (
			id integer not null primary key autoincrement, 
			name text,
			path text,
			date text,
			size integer,
			exif json
			meta json
		);
		create index idx_date on media(date);
	`)
}
