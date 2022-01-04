package sync

type (
	Sync interface {
		Upload(cType string, path string) (string, error)
		Delete(meta string) error
	}
)
