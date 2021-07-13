package model

var (
	dbMigrations []string
)

func init() {
	dbMigrations = append(dbMigrations, `
		create table media (id integer not null primary key, name text);
	`)
}
